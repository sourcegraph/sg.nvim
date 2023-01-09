use {
    ::reqwest::Client,
    anyhow::{Context, Result},
    async_trait::async_trait,
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    interprocess::local_socket::LocalSocketStream,
    mlua::{prelude::*, UserData},
    once_cell::sync::Lazy,
    regex::Regex,
    serde,
    std::{future::Future, sync::Arc},
};

pub mod definition;

static CLIENT: Lazy<Client> = Lazy::new(|| {
    if let Ok(sourcegraph_access_token) = std::env::var("SRC_ACCESS_TOKEN") {
        Client::builder()
            .default_headers(
                std::iter::once((
                    reqwest::header::AUTHORIZATION,
                    reqwest::header::HeaderValue::from_str(&format!(
                        "Bearer {}",
                        sourcegraph_access_token
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

pub const DAEMON_SOCKET: &str = "/tmp/sg-daemon.sock";

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

        let read_runtime = r.clone();
        methods.add_method("read", move |_, remote_file, ()| {
            // TODO: There has to be a cleaner way to write this
            match read_runtime.block_on(remote_file.read()) {
                Ok(val) => Ok(val),
                Err(err) => return Err(err.to_lua_err()),
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

// TODO: Memoize... :)
//  Noah says learn about:
//      inner mutability
//      refcells
pub async fn get_commit_hash(remote: String, revision: String) -> Result<String> {
    // TODO: Could probably make sure that there are not "/" etc.
    if revision.len() == 40 {
        return Ok(revision.to_owned());
    }

    // TODO: How expensive is this?
    let response_body = post_graphql::<CommitQuery, _>(
        &CLIENT,
        "https://sourcegraph.com/.api/graphql",
        commit_query::Variables {
            name: remote.to_string(),
            rev: revision.to_string(),
        },
    )
    .await?;

    Ok(response_body
        .data
        .context("No data")?
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
    let response_body = post_graphql::<FileQuery, _>(
        &CLIENT,
        "https://sourcegraph.com/.api/graphql",
        file_query::Variables {
            name: remote.to_string(),
            rev: commit.to_string(),
            path: path.to_string(),
        },
    )
    .await?;

    Ok(response_body
        .data
        .context("No data")?
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?
        .file
        .context("No matching File")?
        .content
        .split("\n")
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
            "https://sourcegraph.com/{}@{}/-/blob/{}",
            self.remote, self.commit, self.path
        )
    }

    pub async fn read(&self) -> Result<Vec<String>> {
        get_remote_file_contents(&self.remote, &self.commit, &self.path).await
    }

    // pub fn read_sync(&self) -> Result<String> {
    // }
}

fn normalize_url(url: &str) -> String {
    // TODO: This is a bit ugly atm
    let re = Regex::new(r"^/").unwrap();

    re.replace_all(
        &url.clone()
            .to_string()
            .replace("//gh/", "//github.com/")
            .replace("https://sourcegraph.com/", "")
            .replace("sg://", ""),
        "",
    )
    .to_string()
}

// async fn return_raw_commit(_remote: &str, commit: &str) -> Result<String> {
//   Ok(commit.to_string())
// }

pub async fn uri_from_link<Fut>(
    url: &str,
    converter: fn(String, String) -> Fut,
) -> Result<RemoteFile>
where
    Fut: Future<Output = Result<String>>,
{
    let url = normalize_url(url);

    let split: Vec<&str> = url.split("/-/").collect();
    if split.len() != 2 {
        return Err(anyhow::anyhow!("Expected url to be split by /-/"));
    }

    let remote_with_commit = split[0].to_string();
    let mut split_remote: Vec<&str> = remote_with_commit.split("@").collect();
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
    let path_and_args: Vec<&str> = replaced_path.split("?").collect();

    if path_and_args.len() > 2 {
        return Err(anyhow::anyhow!(
            "Too many question marks. Please don't do that"
        ));
    }

    // TODO: Check out split_once for some stuff here.
    let path = path_and_args[0].to_string();
    let (line, col) = if path_and_args.len() == 2 {
        // TODO: We could probably handle a few more cases here :)
        let arg_split: Vec<&str> = path_and_args[1].split(":").collect();

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

const FAILED_TO_WRITE: &'static str = "Failed to write value";
const FAILED_TO_READ: &'static str = "Failed to read value";

#[async_trait]
pub trait RemoteMessage
where
    Self: Sized + Sync,
{
    const NAME: &'static str;

    fn args(&self) -> Vec<rmpv::Value>;
    fn decode<'lua>(args: rmpv::Value) -> Result<Self>;
    fn conv_lua<'lua>(&self, lua: &'lua Lua, response: rmpv::Value) -> LuaResult<LuaValue<'lua>>;
    async fn process(&self) -> Result<rmpv::Value>;

    fn request<'lua>(&self, lua: &'lua Lua) -> LuaResult<LuaValue<'lua>> {
        let mut conn = LocalSocketStream::connect(DAEMON_SOCKET)?;

        let mut vec = vec![Self::NAME.into()];
        vec.extend(self.args());

        let val = rmpv::Value::Array(vec);
        if let Err(_) = rmpv::encode::write_value(&mut conn, &val) {
            return Err(FAILED_TO_WRITE.to_lua_err());
        }

        // Read response
        // TODO: Probably also want to put in the actual error message here...
        let response = rmpv::decode::read_value(&mut conn);
        if let Ok(response) = response {
            self.conv_lua(lua, response)
        } else {
            Err(FAILED_TO_READ.to_lua_err())
        }
    }

    async fn handle(conn: &mut LocalSocketStream, arr: rmpv::Value) -> Result<()> {
        let decoded = Self::decode(arr)?;
        // println!("    Decoded: {:?}", decoded);

        let processed = decoded.process().await?;
        // println!("    Processed: {:?}", processed);

        rmpv::encode::write_value(conn, &processed).context("encode::write_value")
    }
}

pub struct HashMessage {
    pub remote: String,
    pub hash: String,
}

#[async_trait]
impl RemoteMessage for HashMessage {
    const NAME: &'static str = "hash";

    async fn process(&self) -> Result<rmpv::Value> {
        let hash = get_commit_hash(self.remote.clone(), self.hash.clone()).await?;
        Ok(hash.into())
    }

    fn args(&self) -> Vec<rmpv::Value> {
        vec![self.remote.clone().into(), self.hash.clone().into()]
    }

    fn decode(args: rmpv::Value) -> Result<Self> {
        if let rmpv::Value::Array(args) = args {
            Ok(HashMessage {
                remote: args[1].as_str().unwrap().into(),
                hash: args[2].as_str().unwrap().into(),
            })
        } else {
            Err(anyhow::anyhow!("Did not pass an array"))
        }
    }

    fn conv_lua<'lua>(&self, lua: &'lua Lua, response: rmpv::Value) -> LuaResult<LuaValue<'lua>> {
        response.as_str().to_lua(lua)
    }
}

pub struct ContentsMessage {
    pub remote: String,
    pub hash: String,
    pub path: String,
}

#[async_trait]
impl RemoteMessage for ContentsMessage {
    const NAME: &'static str = "contents";

    async fn process(&self) -> Result<rmpv::Value> {
        Ok(rmpv::Value::Array(
            get_remote_file_contents(&self.remote, &self.hash, &self.path)
                .await?
                .into_iter()
                .map(|x| x.into())
                .collect(),
        ))
    }

    fn args(&self) -> Vec<rmpv::Value> {
        vec![
            self.remote.clone().into(),
            self.hash.clone().into(),
            self.path.clone().into(),
        ]
    }

    fn decode<'lua>(args: rmpv::Value) -> Result<Self> {
        if let rmpv::Value::Array(args) = args {
            Ok(ContentsMessage {
                remote: args[1].as_str().unwrap().into(),
                hash: args[2].as_str().unwrap().into(),
                path: args[3].as_str().unwrap().into(),
            })
        } else {
            Err(anyhow::anyhow!("Did not pass an array"))
        }
    }

    fn conv_lua<'lua>(&self, lua: &'lua Lua, response: rmpv::Value) -> LuaResult<LuaValue<'lua>> {
        let tbl = lua.create_table()?;
        if let rmpv::Value::Array(response) = response {
            for line in response {
                tbl.raw_insert(tbl.raw_len() + 1, line.as_str().to_lua(lua)?)?;
            }
        }

        Ok(mlua::Value::Table(tbl))
    }
}

pub struct RemoteFileMessage {
    pub path: String,
}

#[async_trait]
impl RemoteMessage for RemoteFileMessage {
    const NAME: &'static str = "RemoteFile";

    fn args(&self) -> Vec<rmpv::Value> {
        vec![self.path.clone().into()]
    }

    fn decode<'lua>(args: rmpv::Value) -> Result<Self> {
        if let rmpv::Value::Array(args) = args {
            Ok(RemoteFileMessage {
                path: args[1].as_str().unwrap().into(),
            })
        } else {
            Err(anyhow::anyhow!("Did not pass an array"))
        }
    }

    fn conv_lua<'lua>(&self, lua: &'lua Lua, response: rmpv::Value) -> LuaResult<LuaValue<'lua>> {
        // todo!()
        if let rmpv::Value::Array(response) = response {
            // Ok(RemoteFileMessage {
            //   path: args[1].as_str().unwrap().into(),
            // })

            // let path,
            // pub remote: String,
            // pub commit: String,
            // pub path: String,
            // pub line: Option<usize>,
            // pub col: Option<usize>,

            let remote = response[0].as_str().unwrap().to_string();
            let commit = response[1].as_str().unwrap().to_string();
            let path = response[2].as_str().unwrap().to_string();

            // TODO: Need to handle line and column, could be null

            RemoteFile {
                remote,
                commit,
                path,

                // TODO: Clean this up and do gud
                line: match response[3] {
                    rmpv::Value::Integer(line) => Some(line.as_u64().unwrap() as usize),
                    _ => None,
                },
                col: match response[4] {
                    rmpv::Value::Integer(col) => Some(col.as_u64().unwrap() as usize),
                    _ => None,
                },
            }
            .to_lua(lua)

            // todo!()
        } else {
            Err(anyhow::anyhow!("Did not pass an array").to_lua_err())
        }
    }

    async fn process(&self) -> Result<rmpv::Value> {
        // todo!()
        let remote_file = uri_from_link(&self.path, get_commit_hash).await?;
        println!("TESTING: {:?} {:?}", remote_file.line, remote_file.col);

        Ok(rmpv::Value::Array(vec![
            remote_file.remote.into(),
            remote_file.commit.into(),
            remote_file.path.into(),
            remote_file.line.unwrap_or(0).into(),
            remote_file.col.unwrap_or(0).into(),
        ]))
    }
}

#[cfg(test)]
mod test {
    use super::*;

    async fn return_raw_commit(_remote: String, commit: String) -> Result<String> {
        Ok(commit.to_string())
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
