// use once_cell::sync::OnceCell;

use {
    mlua::{prelude::*, Function, LuaSerdeExt, SerializeOptions, Value},
    reqwest,
    serde::Serialize,
    sg::{
        self, get_commit_hash, uri_from_link, ContentsMessage, HashMessage, RemoteFileMessage,
        RemoteMessage,
    },
    std::sync::{Arc, Mutex},
};

// TODO: I would like to be able to do something like this and make a constant.
// but that is apparently impossible
//
// const SERIALIZE_OPTIONS: SerializeOptions = SerializeOptions {...}
pub fn to_lua<'lua, T>(l: &'lua Lua, t: &T) -> LuaResult<Value<'lua>>
where
    T: Serialize + ?Sized,
{
    l.to_value_with(&t, SerializeOptions::new().serialize_none_to_null(false))
}

// This is how you can print easily
fn lua_print(lua: &Lua, str: &str) -> LuaResult<()> {
    let print: Function = lua.globals().get("print")?;
    print.call::<_, ()>(str.to_lua(lua))?;

    Ok(())
}

fn get_remote_hash<'lua>(lua: &'lua Lua, args: (String, String)) -> LuaResult<LuaValue<'lua>> {
    let remote = args.0.clone();
    let hash = args.1.clone();

    HashMessage { remote, hash }.request(lua)
}

fn get_remote_file_content<'lua>(
    lua: &'lua Lua,
    args: (String, String, String),
) -> LuaResult<LuaValue<'lua>> {
    let remote = args.0;
    let hash = args.1;
    let path = args.2;

    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let remote_file = rt
        .block_on(async { sg::get_remote_file_contents(&remote, &hash, &path).await })
        .to_lua_err()
        .expect("get_remote_file_content");

    to_lua(lua, &remote_file)
}

fn get_remote_file<'lua>(lua: &'lua Lua, args: (String,)) -> LuaResult<LuaValue<'lua>> {
    let path = args.0;
    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let remote_file = rt
        .block_on(async { uri_from_link(path.as_str(), get_commit_hash).await })
        .to_lua_err()
        .expect("remote_file: uri_from_link");

    // to_lua(lua, &remote_file)
    remote_file.to_lua(lua)
}

#[mlua::lua_module]
fn libsg_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    // TODO: Consider putting mlua_null as a global so we can compare with that
    // Patatas_del_papa: I was going to ask if doing something like lua.globals().set("null", lua.null())? could be the solution

    let exports = lua.create_table()?;

    exports.set("get_remote_hash", lua.create_function(get_remote_hash)?)?;
    exports.set(
        "get_remote_file_contents",
        lua.create_function(get_remote_file_content)?,
    )?;

    exports.set("get_remote_file", lua.create_function(get_remote_file)?)?;

    Ok(exports)
}
