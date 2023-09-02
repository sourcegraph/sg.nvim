use {
    crate::{
        entry::Entry, get_cody_completions, get_embeddings_context, get_endpoint, get_repository_id,
    },
    anyhow::Result,
    serde::{Deserialize, Serialize},
    serde_json::{json, Value},
    sg_types::{Embedding, RecipeInfo, SearchResult},
    std::{thread, time::Duration},
};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ProtoEntry {
    r#type: String,
    bufname: String,
    data: Entry,
}

impl ProtoEntry {
    pub fn from_entry(entry: Entry) -> Self {
        Self {
            r#type: entry.typename().to_string(),
            bufname: entry.bufname(),
            data: entry,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum Message {
    Request(Request),
    Response(Response),
    Notification(Notification),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Request {
    pub id: usize,

    #[serde(flatten)]
    pub data: RequestData,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method", content = "params")]
pub enum RequestData {
    Echo {
        message: String,
        delay: Option<i32>,
    },

    Complete {
        message: String,
        prefix: Option<String>,
        temperature: Option<f64>,
    },

    Repository {
        name: String,
    },

    Embedding {
        repo: String,
        query: String,
        code: i64,
        text: i64,
    },

    #[serde(rename = "sourcegraph/get_entry")]
    SourcegraphGetEntry {
        path: String,
    },

    #[serde(rename = "sourcegraph/get_file_contents")]
    SourcegraphFileContents {
        remote: String,
        oid: String,
        path: String,
    },

    #[serde(rename = "sourcegraph/get_directory_contents")]
    SourcegraphDirectoryContents {
        remote: String,
        oid: String,
        path: String,
    },

    #[serde(rename = "sourcegraph/search")]
    SourcegraphSearch {
        query: String,
    },

    #[serde(rename = "sourcegraph/info")]
    SourcegraphInfo {
        query: String,
    },

    #[serde(rename = "sourcegraph/link")]
    SourcegraphLink {
        path: String,
        line: usize,
        col: usize,
    },
}

#[allow(unused_variables)]
impl Request {
    pub async fn respond(self) -> Result<Response> {
        let Self { id, data } = self;
        match data {
            RequestData::Echo { message, delay } => {
                if let Some(delay) = delay {
                    thread::sleep(Duration::from_secs(delay as u64));
                }

                Ok(Response::new(id, ResponseData::Echo { message }))
            }
            RequestData::Complete {
                message,
                prefix,
                temperature,
            } => {
                eprintln!("[sg-cody] complete: {id} - {prefix:?}");
                let completion = match get_cody_completions(message, prefix, temperature).await {
                    Ok(completion) => completion,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                    }
                };

                Ok(Response::new(id, ResponseData::Complete { completion }))
            }
            RequestData::Repository { name } => {
                eprintln!("[sg-cody] repo: {id} {name}");
                let repository = match get_repository_id(name).await {
                    Ok(repo) => repo,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get repository: {err:?}"));
                    }
                };

                Ok(Response::new(id, ResponseData::Repository { repository }))
            }
            RequestData::Embedding {
                repo,
                query,
                code,
                text,
            } => {
                eprintln!("[sg-cody] repo: {id} {repo}");
                let embeddings = match get_embeddings_context(repo, query, code, text).await {
                    Ok(embeddings) => embeddings,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get embeddings: {err:?}"));
                    }
                };

                Ok(Response::new(id, ResponseData::Embedding { embeddings }))
            }
            RequestData::SourcegraphGetEntry { path } => {
                let entry = Entry::new(&path).await?;
                Ok(Response::new(
                    id,
                    ResponseData::SourcegraphGetEntry(ProtoEntry::from_entry(entry)),
                ))
            }
            RequestData::SourcegraphFileContents { remote, oid, path } => {
                let contents = crate::get_file_contents(&remote, &oid, &path)
                    .await?
                    .split('\n')
                    .map(|s| s.to_string())
                    .collect::<Vec<String>>();
                Ok(Response::new(
                    id,
                    ResponseData::SourcegraphFileContents(contents),
                ))
            }
            RequestData::SourcegraphDirectoryContents { remote, oid, path } => {
                let contents = crate::get_remote_directory_contents(&remote, &oid, &path)
                    .await?
                    .into_iter()
                    .flat_map(|e| Entry::from_info(e).map(ProtoEntry::from_entry))
                    .collect::<Vec<_>>();

                Ok(Response::new(
                    id,
                    ResponseData::SourcegraphDirectoryContents(contents),
                ))
            }
            RequestData::SourcegraphSearch { query } => {
                let result = crate::get_search(query).await?;
                Ok(Response::new(id, ResponseData::SourcegraphSearch(result)))
            }
            RequestData::SourcegraphInfo { .. } => {
                eprintln!("Got Sg info request");
                let version = crate::get_sourcegraph_version().await?;
                let nvim_version = env!("CARGO_PKG_VERSION");

                let value = json!({
                    "sourcegraph_version": version,
                    "sg_nvim_version": nvim_version,
                    "endpoint": crate::get_endpoint(),
                    "access_token_set": !crate::get_access_token().is_empty()
                });

                Ok(Response::new(id, ResponseData::SourcegraphInfo(value)))
            }
            RequestData::SourcegraphLink { path, line, col } => {
                let link = match Entry::new(&path).await? {
                    Entry::File(file) => {
                        let endpoint = get_endpoint();
                        let remote = file.remote.0;
                        let path = file.path;

                        format!("{endpoint}/{remote}/-/blob/{path}?L{line}-{col}")
                    }
                    Entry::Directory(dir) => {
                        let endpoint = get_endpoint();
                        let remote = dir.remote.0;
                        let path = dir.path;

                        format!("{endpoint}/{remote}/-/tree/{path}")
                    }
                    Entry::Repo(repo) => {
                        let endpoint = get_endpoint();
                        let remote = repo.remote.0;
                        let oid = repo.oid.0;

                        format!("{endpoint}/{remote}@{oid}")
                    }
                };

                Ok(Response::new(id, ResponseData::SourcegraphLink(link)))
            }
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Response {
    pub id: usize,
    pub result: ResponseData,
}

impl Response {
    pub fn new(id: usize, result: ResponseData) -> Self {
        Self { id, result }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum ResponseData {
    Echo { message: String },
    Complete { completion: String },
    Repository { repository: String },
    Embedding { embeddings: Vec<Embedding> },
    ListRecipes { recipes: Vec<RecipeInfo> },
    SourcegraphGetEntry(ProtoEntry),
    SourcegraphFileContents(Vec<String>),
    SourcegraphDirectoryContents(Vec<ProtoEntry>),
    SourcegraphSearch(Vec<SearchResult>),
    SourcegraphInfo(Value),
    SourcegraphLink(String),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Notification {
    UpdateChat { message: String },
    Hack { json: String },
}
