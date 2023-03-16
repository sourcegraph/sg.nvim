use {
    ::reqwest::Client,
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    once_cell::sync::Lazy,
    regex::Regex,
};

pub mod definition;
pub mod entry;
pub mod hover;
pub mod references;
pub mod search;

mod graphql {
    use super::*;

    static GRAPHQL_ENDPOINT: Lazy<String> = Lazy::new(|| {
        let endpoint = get_endpoint().unwrap_or("https://sourcegraph.com/".to_string());
        format!("{endpoint}.api/graphql")
    });

    static CLIENT: Lazy<Client> = Lazy::new(|| {
        if let Ok(sourcegraph_access_token) = get_access_token() {
            Client::builder()
                .default_headers(
                    std::iter::once((
                        reqwest::header::AUTHORIZATION,
                        reqwest::header::HeaderValue::from_str(&format!(
                            "Bearer {sourcegraph_access_token}",
                        ))
                        .unwrap(),
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
        let response =
            match post_graphql::<Q, _>(&CLIENT, GRAPHQL_ENDPOINT.to_string(), variables).await {
                Ok(response) => response,
                Err(err) => {
                    return Err(anyhow::anyhow!(
                        "Failed with status: {:?} || {err:?}",
                        err.status()
                    ))
                }
            };

        response.data.context("get_graphql -> data")
    }
}

pub use graphql::get_graphql;
use serde::Serialize;

pub fn get_access_token() -> Result<String> {
    std::env::var("SOURCEGRAPH_ACCESS_TOKEN").context("No access token found")
}

pub fn get_endpoint() -> Result<String> {
    std::env::var("SRC_ENDPOINT").context("No endpoint found")
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

// TODO: Create some new data types, don't just pass strings please
pub fn normalize_url(url: &str) -> String {
    let re = Regex::new(r"^/").unwrap();

    re.replace_all(
        &url.to_string()
            .replace("//gh/", "//github.com/")
            .replace("https://sourcegraph.com/", "")
            .replace("sg://", ""),
        "",
    )
    .to_string()
}

// pub async fn uri_from_link(url: &str) -> Result<File> {
//     let split: Vec<&str> = url.split("/-/").collect();
//     if split.len() != 2 {
//         return Err(anyhow::anyhow!("Expected url to be split by /-/"));
//     }
//
//     let remote_with_commit = split[0].to_string();
//     let mut split_remote: Vec<&str> = remote_with_commit.split('@').collect();
//     let remote = split_remote.remove(0).to_string();
//     let commit = get_commit_hash(
//         remote.clone(),
//         if split_remote.is_empty() {
//             "HEAD".to_string()
//         } else {
//             split_remote.remove(0).to_string()
//         },
//     )
//     .await?;
//
//     let prefix_regex = Regex::new("^(blob|tree)/")?;
//     let replaced_path = prefix_regex.replace(split[1], "");
//     let path_and_args: Vec<&str> = replaced_path.split('?').collect();
//
//     if path_and_args.len() > 2 {
//         return Err(anyhow::anyhow!(
//             "Too many question marks. Please don't do that"
//         ));
//     }
//
//     // TODO: Check out split_once for some stuff here.
//     let path = path_and_args[0].to_string();
//     let (line, col) = if path_and_args.len() == 2 {
//         // TODO: We could probably handle a few more cases here :)
//         let arg_split: Vec<&str> = path_and_args[1].split(':').collect();
//
//         if arg_split.len() == 2 {
//             (
//                 Some(arg_split[0][1..].parse().unwrap_or(1)),
//                 Some(arg_split[1].parse().unwrap_or(1)),
//             )
//         } else if arg_split.len() == 1 {
//             match arg_split[0][1..].parse() {
//                 Ok(val) => (Some(val), None),
//                 Err(_) => (None, None),
//             }
//         } else {
//             (None, None)
//         }
//     } else {
//         (None, None)
//     };
//
//     Ok(RemoteFile {
//         remote,
//         commit,
//         path,
//         line,
//         col,
//     })
// }
