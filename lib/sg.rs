use {
    ::reqwest::Client,
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    mlua::{prelude::*, UserData},
    once_cell::sync::Lazy,
    regex::Regex,
    std::{future::Future, sync::Arc},
};

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
    std::env::var("SRC_ACCESS_TOKEN").context("No access token found")
}

pub fn get_endpoint() -> String {
    std::env::var("SRC_ENDPOINT")
        .unwrap_or("https://sourcegraph.com".to_string())
        .trim_end_matches('/')
        .to_string()
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct RemoteFile {
    pub remote: String,
    pub commit: String,
    pub path: String,
    pub line: Option<usize>,
    pub col: Option<usize>,
}

impl UserData for RemoteFile {
    fn add_methods<'lua, M: mlua::UserDataMethods<'lua, Self>>(methods: &mut M) {
        let r = Arc::new(tokio::runtime::Runtime::new().unwrap());

        methods.add_method("bufname", |lua, t, ()| t.bufname().to_lua(lua));
        methods.add_method("sourcegraph_url", |lua, t, ()| {
            t.sourcegraph_url().to_lua(lua)
        });

        let read_runtime = r;
        methods.add_method("read", move |_, remote_file, ()| {
            // TODO: There has to be a cleaner way to write this
            match read_runtime.block_on(remote_file.read()) {
                Ok(val) => Ok(val),
                Err(err) => Err(err.to_lua_err()),
            }
        });
    }

    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("remote", |lua, t| t.remote.to_string().to_lua(lua));
        fields.add_field_method_get("commit", |lua, t| t.commit.to_string().to_lua(lua));
        fields.add_field_method_get("path", |lua, t| t.path.to_string().to_lua(lua));

        fields.add_field_method_get("line", |lua, t| match t.line {
            Some(line) => line.to_lua(lua),
            None => Ok(LuaNil),
        });
        fields.add_field_method_get("col", |lua, t| match t.col {
            Some(col) => col.to_lua(lua),
            None => Ok(LuaNil),
        });
    }
}

type GitObjectID = String;

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

// TODO: Memoize... :)
//  Noah says learn about:
//      inner mutability
//      refcells
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

pub async fn get_remote_file_contents(
    remote: &str,
    commit: &str,
    path: &str,
) -> Result<Vec<String>> {
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
        .content
        .split('\n')
        .map(|x| x.to_string())
        .collect())
}

impl RemoteFile {
    fn shortened_remote(&self) -> String {
        if self.remote == "github.com" {
            "gh".to_string()
        } else {
            self.remote.to_owned()
        }
    }

    fn shortened_commit(&self) -> String {
        self.commit[..5].to_string()
    }

    pub fn bufname(&self) -> String {
        format!(
            "sg://{}@{}/-/{}",
            self.shortened_remote(),
            self.shortened_commit(),
            self.path
        )
    }

    pub fn sourcegraph_url(&self) -> String {
        format!(
            "{}/{}@{}/-/blob/{}",
            get_endpoint(),
            self.remote,
            self.commit,
            self.path
        )
    }

    pub async fn read(&self) -> Result<Vec<String>> {
        get_remote_file_contents(&self.remote, &self.commit, &self.path).await
    }
}

// TODO: Create some new data types, don't just pass strings please
pub fn normalize_url(url: &str) -> String {
    let re = Regex::new(r"^/").unwrap();

    re.replace_all(
        &url.to_string()
            .replace("//gh/", "//github.com/")
            .replace(&get_endpoint(), "")
            .replace("sg://", ""),
        "",
    )
    .to_string()
}

pub async fn uri_from_link<Fut>(
    url: &str,
    converter: fn(String, String) -> Fut,
) -> Result<RemoteFile>
where
    Fut: Future<Output = Result<String>>,
{
    let split: Vec<&str> = url.split("/-/").collect();
    if split.len() != 2 {
        return Err(anyhow::anyhow!("Expected url to be split by /-/"));
    }

    let remote_with_commit = split[0].to_string();
    let mut split_remote: Vec<&str> = remote_with_commit.split('@').collect();
    let remote = split_remote.remove(0).to_string();
    let commit = converter(
        remote.clone(),
        if split_remote.is_empty() {
            "HEAD".to_string()
        } else {
            split_remote.remove(0).to_string()
        },
    )
    .await?;

    let prefix_regex = Regex::new("^(blob|tree)/")?;
    let replaced_path = prefix_regex.replace(split[1], "");
    let path_and_args: Vec<&str> = replaced_path.split('?').collect();

    if path_and_args.len() > 2 {
        return Err(anyhow::anyhow!(
            "Too many question marks. Please don't do that"
        ));
    }

    // TODO: Check out split_once for some stuff here.
    let path = path_and_args[0].to_string();
    let (line, col) = if path_and_args.len() == 2 {
        // TODO: We could probably handle a few more cases here :)
        let arg_split: Vec<&str> = path_and_args[1].split(':').collect();

        if arg_split.len() == 2 {
            (
                Some(arg_split[0][1..].parse().unwrap_or(1)),
                Some(arg_split[1].parse().unwrap_or(1)),
            )
        } else if arg_split.len() == 1 {
            match arg_split[0][1..].parse() {
                Ok(val) => (Some(val), None),
                Err(_) => (None, None),
            }
        } else {
            (None, None)
        }
    } else {
        (None, None)
    };

    Ok(RemoteFile {
        remote,
        commit,
        path,
        line,
        col,
    })
}

pub struct HashMessage {
    pub remote: String,
    pub hash: String,
}

pub struct ContentsMessage {
    pub remote: String,
    pub hash: String,
    pub path: String,
}

pub struct RemoteFileMessage {
    pub path: String,
}

#[cfg(test)]
mod test {
    use super::*;

    async fn return_raw_commit(_remote: String, commit: String) -> Result<String> {
        Ok(commit)
    }

    #[tokio::test]
    async fn create() -> Result<()> {
        let test_cases = vec![
            "https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c",
            "https://sourcegraph.com/github.com/neovim/neovim/-/tree/src/nvim/autocmd.c",
            "sg://github.com/neovim/neovim/-/blob/src/nvim/autocmd.c",
            "sg://github.com/neovim/neovim/-/tree/src/nvim/autocmd.c",
            "sg://gh/neovim/neovim/-/blob/src/nvim/autocmd.c",
            "sg://gh/neovim/neovim/-/tree/src/nvim/autocmd.c",
            "sg://github.com/neovim/neovim/-/src/nvim/autocmd.c",
            "sg://gh/neovim/neovim/-/src/nvim/autocmd.c",
        ];

        for tc in test_cases {
            let x = uri_from_link(tc, return_raw_commit).await?;

            assert_eq!(x.remote, "github.com/neovim/neovim");
            assert_eq!(x.commit, "HEAD");
            assert_eq!(x.path, "src/nvim/autocmd.c");
            assert_eq!(x.line, None);
            assert_eq!(x.col, None);
        }

        Ok(())
    }

    #[tokio::test]
    async fn can_get_lines_and_columns() -> Result<()> {
        let test_case =
            "sg://github.com/sourcegraph/sourcegraph@main/-/blob/dev/sg/rfc.go?L29:2".to_string();

        let remote_file = uri_from_link(&test_case, return_raw_commit).await?;
        assert_eq!(remote_file.remote, "github.com/sourcegraph/sourcegraph");
        assert_eq!(remote_file.path, "dev/sg/rfc.go");
        assert_eq!(remote_file.line, Some(29));
        assert_eq!(remote_file.col, Some(2));

        Ok(())
    }
}
