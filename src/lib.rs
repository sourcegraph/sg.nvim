use {
    anyhow::Result, graphql_client::GraphQLQuery, lsp_types::Location, once_cell::sync::Lazy,
    regex::Regex, reqwest::Client, sg_gql::user::UserInfo, sg_types::*,
};

pub mod auth;
pub mod entry;
pub mod nvim;

pub fn normalize_url(url: &str) -> String {
    let re = Regex::new(r"^/").unwrap();

    re.replace_all(
        &url.to_string()
            .replace(get_endpoint(), "")
            .replace("//gh/", "//github.com/")
            .replace("sg://", ""),
        "",
    )
    .to_string()
}

mod graphql {
    use {super::*, futures::Future};

    static GRAPHQL_ENDPOINT: Lazy<String> = Lazy::new(|| {
        let endpoint = get_endpoint();
        format!("{endpoint}/.api/graphql")
    });

    static CLIENT: Lazy<Client> = Lazy::new(|| {
        let sourcegraph_access_token = get_access_token();
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
    });

    pub async fn request_wrap<Q: GraphQLQuery, F, T, R>(
        variables: impl Into<Q::Variables>,
        get: F,
    ) -> Result<T>
    where
        F: Fn(&'static Client, String, Q::Variables) -> R,
        R: Future<Output = Result<T>>,
        T: Sized,
    {
        get(&CLIENT, GRAPHQL_ENDPOINT.to_string(), variables.into()).await
    }
}

macro_rules! wrap_request {
    ($path:path, $variables: expr) => {{
        use $path::*;
        graphql::request_wrap::<Query, _, _, _>($variables, request).await
    }};
}

pub fn get_access_token() -> &'static str {
    static TOKEN: Lazy<String> =
        Lazy::new(|| std::env::var("SRC_ACCESS_TOKEN").expect("No access token found"));

    &TOKEN
}

pub fn get_endpoint() -> &'static str {
    static ENDPOINT: Lazy<String> = Lazy::new(|| {
        std::env::var("SRC_ENDPOINT")
            .unwrap_or_else(|_| "https://sourcegraph.com/".to_string())
            .trim_end_matches('/')
            .to_string()
    });

    &ENDPOINT
}

pub async fn get_path_info(remote: String, revision: String, path: String) -> Result<PathInfo> {
    // Get rid of double slashes, since that messes up Sourcegraph API
    let remote = remote.replace("//", "/");

    wrap_request!(
        sg_gql::path_info,
        Variables {
            name: remote,
            revision,
            path
        }
    )
}

pub async fn get_remote_directory_contents(
    remote: &str,
    commit: &str,
    path: &str,
) -> Result<Vec<PathInfo>> {
    wrap_request!(
        sg_gql::list_files,
        Variables {
            name: remote.to_string(),
            rev: commit.to_string(),
            path: path.to_string()
        }
    )
}

pub async fn get_commit_hash(remote: String, revision: String) -> Result<String> {
    if revision.len() == 40 {
        return Ok(revision);
    }

    wrap_request!(
        sg_gql::commit_oid,
        Variables {
            name: remote,
            rev: revision
        }
    )
}

pub async fn get_file_contents(remote: &str, commit: &str, path: &str) -> Result<String> {
    wrap_request!(
        sg_gql::file,
        Variables {
            name: remote.to_string(),
            rev: commit.to_string(),
            path: path.to_string(),
        }
    )
}

pub async fn get_sourcegraph_version() -> Result<SourcegraphVersion> {
    wrap_request!(sg_gql::sourcegraph_version, Variables {})
}

pub async fn get_embeddings_context(
    repo: ID,
    query: String,
    code: i64,
    text: i64,
) -> Result<Vec<Embedding>> {
    wrap_request!(
        sg_gql::embeddings_context,
        Variables {
            repo,
            query,
            code,
            text,
        }
    )
}

pub async fn get_hover(uri: String, line: i64, character: i64) -> Result<String> {
    let remote_file = entry::Entry::new(&uri).await?;
    let remote_file = match remote_file {
        entry::Entry::File(file) => file,
        _ => return Err(anyhow::anyhow!("Can only get references of a file")),
    };

    wrap_request!(
        sg_gql::hover,
        Variables {
            repository: remote_file.remote.0,
            revision: remote_file.oid.0,
            path: remote_file.path,
            line,
            character,
        }
    )
}

pub async fn get_repository_id(name: String) -> Result<String> {
    wrap_request!(sg_gql::repository_id, Variables { name })
}

pub async fn get_cody_completions(
    text: String,
    prefix: Option<String>,
    temperature: Option<f64>,
) -> Result<String> {
    // TODO: Figure out how to deal with messages

    let messages = vec![
            CodyMessage {
                speaker: CodySpeaker::Assistant,
                text: "I am Cody, an AI-powered coding assistant developed by Sourcegraph. I operate inside a Language Server Protocol implementation. My task is to help programmers with programming tasks in the %s programming language.
    I have access to your currently open files in the editor.
    I will generate suggestions as concisely and clearly as possible.
    I only suggest something if I am certain about my answer.".to_string(),
            },
            CodyMessage {
                speaker: CodySpeaker::Human,
                text,
            },
            CodyMessage {
                speaker: CodySpeaker::Assistant,
                text: prefix.unwrap_or("".to_string()),
            },
        ];

    wrap_request!(
        sg_gql::cody_completion,
        Variables {
            messages,
            temperature,
        }
    )
}

pub async fn get_definitions(
    uri: String,
    line: i64,
    character: i64,
) -> Result<Vec<lsp_types::Location>> {
    // TODO: Could put the line and character in here directly as well...
    let remote_file = entry::Entry::new(&uri).await?;
    let remote_file = match remote_file {
        entry::Entry::File(file) => file,
        _ => return Err(anyhow::anyhow!("Can only get references of a file")),
    };

    wrap_request!(
        sg_gql::definition,
        Variables {
            repository: remote_file.remote.0,
            revision: remote_file.oid.0,
            path: remote_file.path,
            line,
            character,
        }
    )
}

pub async fn get_references(uri: String, line: i64, character: i64) -> Result<Vec<Location>> {
    let remote_file = entry::Entry::new(&uri).await?;
    let remote_file = match remote_file {
        entry::Entry::File(file) => file,
        _ => return Err(anyhow::anyhow!("Can only get references of a file")),
    };

    wrap_request!(
        sg_gql::references,
        Variables {
            repository: remote_file.remote.0,
            revision: remote_file.oid.0,
            path: remote_file.path,
            line,
            character,
        }
    )
}

pub async fn get_search(query: String) -> Result<Vec<SearchResult>> {
    wrap_request!(sg_gql::search, Variables { query })
}

pub async fn get_user_info() -> Result<UserInfo> {
    wrap_request!(sg_gql::user, Variables {})
}
