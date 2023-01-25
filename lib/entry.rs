use {
    crate::{get_path_info, normalize_url, PathInfo},
    anyhow::Result,
    mlua::{ToLua, UserData},
    regex::Regex,
    std::str::FromStr,
    userdata_defaults::LuaDefaults,
};

pub enum Entry {
    File(File),
    Directory(Directory),
    Repo(Repo),
}

impl Entry {
    pub async fn new(uri: &str) -> Result<Self> {
        let uri = normalize_url(uri);
        let (remote_with_commit, path) = uri.split_once("/-/").ok_or(anyhow::anyhow!(
            "URL must have at least one '-' for it to be valid"
        ))?;

        if path.is_empty() {
            todo!("Handled repos, not files")
        }

        let (remote, commit) = remote_with_commit
            .split_once('@')
            .unwrap_or((remote_with_commit, "HEAD"));

        let prefix_regex = Regex::new("^(blob|tree)/")?;
        let path = prefix_regex.replace(path, "").to_string();

        // TODO: Not sure if you can have question marks in filepaths for github...
        //      Will need to test that out later
        let (path, args) = path.split_once('?').unwrap_or((&path, ""));

        let PathInfo {
            remote,
            oid,
            path,
            is_directory,
        } = get_path_info(remote.to_string(), commit.to_string(), path.to_string()).await?;

        if is_directory {
            Ok(Self::Directory(Directory {
                remote: remote.parse()?,
                oid: oid.parse()?,
                path,
            }))
        } else {
            // let position = {
            //     // TODO: We could probably handle a few more cases here :)
            //     let arg_split: Vec<&str> = args.split(':').collect();
            //
            //     if arg_split.len() == 2 {
            //         Position {
            //             line: Some(arg_split[0][1..].parse().unwrap_or(1)),
            //             col: Some(arg_split[1].parse().unwrap_or(1)),
            //         }
            //     } else if arg_split.len() == 1 {
            //         match arg_split[0][1..].parse() {
            //             Ok(val) => Position {
            //                 line: Some(val),
            //                 col: None,
            //             },
            //             Err(_) => Position::default(),
            //         }
            //     } else {
            //         Position::default()
            //     }
            // };
            let position = Position::default();

            Ok(Self::File(File {
                remote: remote.parse()?,
                oid: oid.parse()?,
                path,
                position,
            }))
        }
    }
}

impl<'lua> ToLua<'lua> for Entry {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        let tbl = lua.create_table()?;

        tbl.set(
            "type",
            match self {
                Entry::File(_) => "file",
                Entry::Directory(_) => "directory",
                Entry::Repo(_) => "repo",
            },
        )?;

        tbl.set(
            "data",
            match self {
                Entry::File(file) => file.to_lua(lua)?,
                Entry::Directory(dir) => dir.to_lua(lua)?,
                Entry::Repo(_) => todo!(),
            },
        )?;

        Ok(mlua::Value::Table(tbl))
    }
}

#[derive(Clone)]
pub struct Remote {
    inner: String,
}
impl<'lua> ToLua<'lua> for Remote {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        self.inner.to_lua(lua)
    }
}

impl FromStr for Remote {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self {
            inner: s.to_string(),
        })
    }
}

#[derive(Clone)]
pub struct OID {
    inner: String,
}
impl<'lua> ToLua<'lua> for OID {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        self.inner.to_lua(lua)
    }
}

impl FromStr for OID {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self {
            inner: s.to_string(),
        })
    }
}

#[derive(Clone, Default)]
pub struct Position {
    line: Option<usize>,
    col: Option<usize>,
}
impl<'lua> ToLua<'lua> for Position {
    fn to_lua(self, _lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        Ok(match (self.line, self.col) {
            (None, None) => mlua::Nil,
            (_line, _col) => todo!("make a table..."),
        })
    }
}

#[derive(LuaDefaults)]
pub struct File {
    pub remote: Remote,
    pub oid: OID,
    pub path: String,
    pub position: Position,
}

impl File {
    fn shortened_remote(&self) -> String {
        if self.remote.inner == "github.com" {
            "gh".to_string()
        } else {
            self.remote.inner.to_owned()
        }
    }

    fn shortened_commit(&self) -> String {
        self.oid.inner[..5].to_string()
    }

    pub fn bufname(&self) -> String {
        format!(
            "sg://{}@{}/-/{}",
            self.shortened_remote(),
            self.shortened_commit(),
            self.path
        )
    }
}

impl UserData for File {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        File::generate_default_fields(fields);

        fields.add_field_method_get("bufname", |lua, file| file.bufname().to_lua(lua))
    }
}

#[derive(LuaDefaults)]
pub struct Directory {
    pub remote: Remote,
    pub oid: OID,
    pub path: String,
}

impl UserData for Directory {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        Directory::generate_default_fields(fields);
    }
}

pub struct Repo {
    pub remote: Remote,
}
