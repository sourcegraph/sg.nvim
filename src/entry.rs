use {
    crate::{get_path_info, normalize_url, PathInfo},
    anyhow::Result,
    mlua::{ToLua, UserData},
    regex::Regex,
    sg_types::*,
    userdata_defaults::LuaDefaults,
};

#[derive(Debug)]
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
        let (path, _) = path.split_once('?').unwrap_or((&path, ""));

        let info = get_path_info(remote.to_string(), commit.to_string(), path.to_string()).await?;
        Self::from_info(info)
    }

    pub fn from_info(info: PathInfo) -> Result<Self> {
        let PathInfo {
            remote,
            oid,
            path,
            is_directory,
        } = info;

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

    fn bufname(&self) -> String {
        match self {
            Entry::File(file) => file.bufname(),
            Entry::Directory(dir) => dir.bufname(),
            Entry::Repo(_) => todo!(),
        }
    }

    fn position(&self) -> Option<Position> {
        match self {
            Entry::File(file) => Some(file.position.clone()),
            Entry::Directory(_) => None,
            Entry::Repo(_) => None,
        }
    }
}

impl std::convert::TryFrom<Entry> for lsp_types::Location {
    type Error = anyhow::Error;

    fn try_from(value: Entry) -> Result<Self, Self::Error> {
        use lsp_types::Url;

        let position = match value.position() {
            Some(Position {
                line: Some(line),
                col: Some(col),
            }) => lsp_types::Position::new(line as u32, col as u32),
            Some(Position {
                line: Some(line),
                col: None,
            }) => lsp_types::Position::new(line as u32, 0),
            _ => lsp_types::Position::default(),
        };

        Ok(Self {
            uri: Url::parse(&value.bufname())?,
            range: lsp_types::Range {
                start: position,
                end: position,
            },
        })
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

        tbl.set("bufname", self.bufname())?;

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

#[derive(Debug, Clone, Default)]
pub struct Position {
    pub line: Option<usize>,
    pub col: Option<usize>,
}
impl<'lua> ToLua<'lua> for Position {
    fn to_lua(self, _lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        Ok(match (self.line, self.col) {
            (None, None) => mlua::Nil,
            (_line, _col) => todo!("make a table..."),
        })
    }
}

fn make_bufname(remote: &Remote, oid: &OID, path: &str) -> String {
    format!("sg://{}@{}/-/{}", remote.shortened(), oid.shortened(), path)
}

#[derive(Debug, LuaDefaults)]
pub struct File {
    pub remote: Remote,
    pub oid: OID,
    pub path: String,
    pub position: Position,
}

impl File {
    pub fn bufname(&self) -> String {
        make_bufname(&self.remote, &self.oid, &self.path)
    }
}

impl UserData for File {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        File::generate_default_fields(fields);
    }
}

#[derive(Debug, LuaDefaults)]
pub struct Directory {
    pub remote: Remote,
    pub oid: OID,
    pub path: String,
}

impl Directory {
    pub fn bufname(&self) -> String {
        make_bufname(&self.remote, &self.oid, &self.path)
    }
}

impl UserData for Directory {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        Directory::generate_default_fields(fields);
    }
}

#[derive(Debug)]
pub struct Repo {
    pub remote: Remote,
}
