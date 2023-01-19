use {
    mlua::{ToLua, UserData},
    userdata_defaults::LuaDefaults,
};

pub enum Entry {
    File(File),
    Directory(Directory),
    Repo(Repo),
}

#[derive(Clone)]
pub struct Remote {}
impl<'lua> ToLua<'lua> for Remote {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        Ok(mlua::Nil)
    }
}

#[derive(Clone)]
pub struct Commit {}
impl<'lua> ToLua<'lua> for Commit {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        Ok(mlua::Nil)
    }
}

#[derive(Clone)]
pub struct Position {}
impl<'lua> ToLua<'lua> for Position {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        Ok(mlua::Nil)
    }
}

#[derive(LuaDefaults)]
pub struct File {
    pub remote: Remote,
    pub commit: Commit,
    pub path: String,
    pub position: Option<Position>,
}

impl UserData for File {
    fn add_fields<'lua, F: mlua::UserDataFields<'lua, Self>>(fields: &mut F) {
        File::generate_default_fields(fields);
    }
}

pub struct Directory {
    pub remote: Remote,
    pub commit: Commit,
    pub path: String,
}

pub struct Repo {
    pub remote: Remote,
}
