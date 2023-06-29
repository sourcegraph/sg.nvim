use {
    ::reqwest::Client,
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    once_cell::sync::Lazy,
    regex::Regex,
    serde::Serialize,
    sg_types::*,
};

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

pub mod definition;
pub mod entry;
pub mod references;
pub mod search;

mod graphql {
    use {super::*, futures::Future};

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

    pub async fn request_wrap<Q: GraphQLQuery, F, T, R>(
        variables: Q::Variables,
        get: F,
    ) -> Result<T>
    where
        F: Fn(&'static Client, String, Q::Variables) -> R,
        R: Future<Output = Result<T>>,
        T: Sized,
    {
        get(&CLIENT, GRAPHQL_ENDPOINT.to_string(), variables).await
    }
}

macro_rules! wrap_request {
    ($path:path, $variables: expr) => {{
        use $path::*;
        graphql::request_wrap::<Query, _, _, _>($variables, request).await
    }};
}

pub fn get_access_token() -> Result<String> {
    std::env::var("SRC_ACCESS_TOKEN").context("No access token found")
}

pub fn get_endpoint() -> String {
    std::env::var("SRC_ENDPOINT")
        .unwrap_or_else(|_| "https://sourcegraph.com/".to_string())
        .trim_end_matches('/')
        .to_string()
}

pub async fn get_path_info(remote: String, revision: String, path: String) -> Result<PathInfo> {
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

// #[derive(GraphQLQuery)]
// #[graphql(
//     schema_path = "gql/schema.graphql",
//     query_path = "gql/version_query.graphql",
//     response_derives = "Debug"
// )]
// pub struct VersionQuery;

pub struct SourcegraphVersion {
    pub product: String,
    pub build: String,
}

pub async fn get_sourcegraph_version() -> Result<SourcegraphVersion> {
    // get_graphql::<VersionQuery>(version_query::Variables {})
    //     .await
    //     .map(|response_body| {
    //         let version = response_body.site;
    //         SourcegraphVersion {
    //             product: version.product_version,
    //             build: version.build_version,
    //         }
    //     })
    todo!()
}

pub async fn get_embeddings_context(
    repo: ID,
    query: String,
    code: i64,
    text: i64,
) -> Result<Vec<Embedding>> {
    // let response = get_graphql::<EmbeddingsContextQuery>(embeddings_context_query::Variables {
    //     repo,
    //     query,
    //     code,
    //     text,
    // })
    // .await?;

    todo!()
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

pub async fn get_cody_completions(text: String, temp: Option<f64>) -> Result<String> {
    // TODO: Figure out how to deal with messages
    let variables = sg_gql::cody_completion::Variables {
        messages: vec![],
        temperature: temp.unwrap_or(0.5),
        max_tokens_to_sample: 1000,
        top_k: -1,
        top_p: -1,
    };

    let _ = graphql::request_wrap::<sg_gql::cody_completion::Query, _, _, _>(
        variables,
        sg_gql::cody_completion::request,
    )
    .await?;

    todo!()
}
