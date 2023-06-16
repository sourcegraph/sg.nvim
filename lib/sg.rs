use {
    ::reqwest::Client,
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    once_cell::sync::Lazy,
    regex::Regex,
};

pub mod cody;
pub mod definition;
pub mod entry;
pub mod hover;
pub mod references;
pub mod search;

mod graphql {
    use super::*;

    static GRAPHQL_ENDPOINT: Lazy<String> = Lazy::new(|| {
        let endpoint = get_endpoint();
        format!("{endpoint}/.api/graphql")
    });

    static CLIENT: Lazy<Client> = Lazy::new(|| {
        if let Ok(sourcegraph_access_token) = get_access_token() {
            Client::builder()
                .default_headers(
                    std::iter::once((
                        reqwest::header::AUTHORIZATION,
                        reqwest::header::HeaderValue::from_str(&format!(
                            "token {sourcegraph_access_token}",
                        ))
                        .expect("to be able to create the header value"),
                    ))
                    .collect(),
                )
                .build()
                .expect("to be able to create the client")
        } else {
            Client::builder()
                .build()
                .expect("to be able to create the client")
        }
    });

    pub async fn get_graphql<Q: GraphQLQuery>(variables: Q::Variables) -> Result<Q::ResponseData> {
        let vars_ser = serde_json::to_string(&variables)?;
        let response =
            match post_graphql::<Q, _>(&CLIENT, GRAPHQL_ENDPOINT.to_string(), variables).await {
                Ok(response) => response,
                Err(err) => {
                    return Err(anyhow::anyhow!(
                        "Failed with (OH NO) status: {:?} || {err:?} TESTING: {}",
                        err.status(),
                        vars_ser
                    ))
                }
            };

        if let Some(errors) = response.errors {
            return Err(anyhow::anyhow!("Errors in response: {:?}", errors));
        }

        response.data.context("get_graphql -> data")
    }
}

pub use graphql::get_graphql;
use serde::{Deserialize, Serialize};

pub fn get_access_token() -> Result<String> {
    std::env::var("SRC_ACCESS_TOKEN").context("No access token found")
}

pub fn get_endpoint() -> String {
    std::env::var("SRC_ENDPOINT")
        .unwrap_or_else(|_| "https://sourcegraph.com/".to_string())
        .trim_end_matches('/')
        .to_string()
}

pub type GitObjectID = String;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/file_query.graphql",
    response_derives = "Debug"
)]
pub struct FileQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/commit_query.graphql",
    response_derives = "Debug"
)]
pub struct CommitQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/path_info_query.graphql",
    response_derives = "Debug"
)]
pub struct PathInfoQuery;

#[derive(Serialize)]
pub struct PathInfo {
    pub remote: String,
    pub oid: String,
    // TODO: Maybe should split out path and name...
    //          Or just always include path, don't just include name
    //          Just do the string manipulation to show the end of the path
    pub path: String,
    pub is_directory: bool,
}

pub async fn get_path_info(remote: String, revision: String, path: String) -> Result<PathInfo> {
    use path_info_query::*;
    let failure = format!("Failed with {}, {}, {}", &remote, &revision, &path);

    let response_body = get_graphql::<PathInfoQuery>(Variables {
        name: remote.to_string(),
        revision,
        path,
    })
    .await?;

    let repository = response_body
        .repository
        .context("No matching repository found")?;

    let commit = repository.commit.context("No matching commit found")?;
    let oid = commit.abbreviated_oid;

    let gql_path = commit
        .path
        .ok_or_else(|| anyhow::anyhow!(failure + ": path"))?;

    let is_directory = match &gql_path {
        PathInfoQueryRepositoryCommitPath::GitTree(tree) => tree.is_directory,
        PathInfoQueryRepositoryCommitPath::GitBlob(blob) => blob.is_directory,
    };

    let path = match gql_path {
        PathInfoQueryRepositoryCommitPath::GitTree(tree) => tree.path,
        PathInfoQueryRepositoryCommitPath::GitBlob(blob) => blob.path,
    };

    Ok(PathInfo {
        remote: repository.name,
        oid,
        path,
        is_directory,
    })
}

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/list_files.graphql",
    response_derives = "Debug"
)]
pub struct ListFilesQuery;

pub async fn get_remote_directory_contents(
    remote: &str,
    commit: &str,
    path: &str,
) -> Result<Vec<PathInfo>> {
    let response_body = get_graphql::<ListFilesQuery>(list_files_query::Variables {
        name: remote.to_string(),
        rev: commit.to_string(),
        path: path.to_string(),
    })
    .await?;

    let commit = response_body
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?;

    let oid = commit.abbreviated_oid;
    Ok(commit
        .tree
        .context("expected tree")?
        .entries
        .into_iter()
        .map(|e| PathInfo {
            remote: remote.to_string(),
            oid: oid.clone(),
            path: e.path,
            is_directory: e.is_directory,
        })
        .collect())
}

pub async fn get_commit_hash(remote: String, revision: String) -> Result<String> {
    if revision.len() == 40 {
        return Ok(revision.to_owned());
    }

    let response_body = get_graphql::<CommitQuery>(commit_query::Variables {
        name: remote.to_string(),
        rev: revision.to_string(),
    })
    .await?;

    Ok(response_body
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?
        .oid)
}

pub async fn get_remote_file_contents(remote: &str, commit: &str, path: &str) -> Result<String> {
    let response_body = get_graphql::<FileQuery>(file_query::Variables {
        name: remote.to_string(),
        rev: commit.to_string(),
        path: path.to_string(),
    })
    .await?;

    Ok(response_body
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?
        .file
        .context("No matching File")?
        .content)
}

pub async fn maybe_read_stuff(remote: &str, commit: &str, path: &str) -> Result<String> {
    // let file = entry::File {
    //     remote: entry::Remote(remote.to_string()),
    //     oid: entry::OID(commit.to_string()),
    //     path: path.to_string(),
    //     position: entry::Position::default(),
    // };

    // let result = db::get_remote_file_contents(&file).await?;
    // if let Some(result) = result {
    //     return Ok(result);
    // }

    get_remote_file_contents(remote, commit, path).await
}

pub fn normalize_url(url: &str) -> String {
    let re = Regex::new(r"^/").unwrap();

    re.replace_all(
        &url.to_string()
            .replace(&get_endpoint(), "")
            .replace("//gh/", "//github.com/")
            .replace("sg://", ""),
        "",
    )
    .to_string()
}

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/version_query.graphql",
    response_derives = "Debug"
)]
pub struct VersionQuery;

pub struct SourcegraphVersion {
    pub product: String,
    pub build: String,
}

pub async fn get_sourcegraph_version() -> Result<SourcegraphVersion> {
    get_graphql::<VersionQuery>(version_query::Variables {})
        .await
        .map(|response_body| {
            let version = response_body.site;
            SourcegraphVersion {
                product: version.product_version,
                build: version.build_version,
            }
        })
}

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/repo.graphql",
    response_derives = "Debug"
)]
pub struct RepoQuery;

pub async fn get_repo(name: String) -> Result<String> {
    let response = get_graphql::<RepoQuery>(repo_query::Variables { name }).await?;
    match response.repository {
        Some(repo) => Ok(repo.id),
        None => Err(anyhow::anyhow!("Could not find repo")),
    }
}

pub type ID = String;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/embeddings_context.graphql",
    response_derives = "Debug"
)]
pub struct EmbeddingsContextQuery;

#[derive(Debug, Serialize, Deserialize)]
pub enum Embedding {
    Code {
        repo: String,
        file: String,
        start: usize,
        finish: usize,
        content: String,
    },
    Text {
        repo: String,
        file: String,
        start: usize,
        finish: usize,
        content: String,
    },
}

pub async fn get_embeddings_context(
    repo: ID,
    query: String,
    code: i64,
    text: i64,
) -> Result<Vec<Embedding>> {
    let response = get_graphql::<EmbeddingsContextQuery>(embeddings_context_query::Variables {
        repo,
        query,
        code,
        text,
    })
    .await?;

    let mut embeddings = vec![];
    for result in response.embeddings_search.code_results {
        embeddings.push(Embedding::Code {
            repo: result.repo_name,
            file: result.file_name,
            start: result.start_line as usize,
            finish: result.end_line as usize,
            content: result.content,
        })
    }

    for result in response.embeddings_search.text_results {
        embeddings.push(Embedding::Text {
            repo: result.repo_name,
            file: result.file_name,
            start: result.start_line as usize,
            finish: result.end_line as usize,
            content: result.content,
        })
    }

    Ok(embeddings)
}
