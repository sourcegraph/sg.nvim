// use once_cell::sync::OnceCell;

use {
    mlua::{prelude::*, Function, LuaSerdeExt, SerializeOptions, Value},
    serde::Serialize,
    sg::{self, entry::Entry, get_access_token, get_endpoint, get_sourcegraph_version, search},
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

#[allow(unused)]
fn lua_print(lua: &Lua, str: &str) -> LuaResult<()> {
    let print: Function = lua.globals().get("print")?;
    print.call::<_, ()>(str.to_lua(lua))?;

    Ok(())
}

fn get_remote_file_contents(lua: &Lua, args: (String, String, String)) -> LuaResult<LuaValue> {
    let remote = args.0;
    let hash = args.1;
    let path = args.2;

    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let remote_file = rt
        .block_on(async { sg::maybe_read_stuff(&remote, &hash, &path).await })
        .to_lua_err()?;

    to_lua(
        lua,
        &remote_file
            .split('\n')
            .map(|s| s.to_string())
            .collect::<Vec<String>>(),
    )
}

fn get_remote_directory_contents(lua: &Lua, args: (String, String, String)) -> LuaResult<LuaValue> {
    let remote = args.0;
    let hash = args.1;
    let path = args.2;

    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let directory_contents = rt
        .block_on(async {
            sg::get_remote_directory_contents(&remote, &hash, &path)
                .await
                .map(|v| {
                    v.into_iter()
                        .map(|e| Entry::from_info(e).expect("these better convert"))
                        .collect::<Vec<_>>()
                })
        })
        .to_lua_err()?;

    directory_contents.to_lua(lua)
}

fn get_search(lua: &Lua, args: (String,)) -> LuaResult<LuaValue> {
    let path = args.0;
    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let search_results = rt
        .block_on(async { search::get_search(path.as_str()).await })
        .to_lua_err()
        .expect("remote_file: uri_from_link");

    Ok(search_results
        .into_iter()
        .map(|res| {
            let mapped = lua.create_table().unwrap();
            mapped.set("repo", res.repo).unwrap();
            mapped.set("file", res.file).unwrap();
            mapped.set("preview", res.preview).unwrap();
            mapped.set("line", res.line).unwrap();
            mapped
        })
        .collect::<Vec<_>>()
        .to_lua(lua)
        .unwrap())
}

fn lua_get_entry(lua: &Lua, args: (String,)) -> LuaResult<LuaValue> {
    let path = args.0;

    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let search_results = rt
        .block_on(async { Entry::new(&path).await })
        .to_lua_err()
        .expect("get_entry");

    search_results.to_lua(lua)
}

fn get_info(lua: &Lua, _: ()) -> LuaResult<LuaValue> {
    let rt = tokio::runtime::Runtime::new().to_lua_err()?;

    let tbl = lua.create_table()?;

    tbl.set(
        "sourcegraph_version",
        match rt.block_on(async { get_sourcegraph_version().await }) {
            Ok(version) => {
                let version_tbl = lua.create_table()?;
                version_tbl.set("build", version.build)?;
                version_tbl.set("product", version.product)?;

                version_tbl.to_lua(lua)?
            }
            Err(err) => format!("error while retrieving version: {}", err).to_lua(lua)?,
        },
    )?;

    tbl.set("sg_nvim_version", env!("CARGO_PKG_VERSION"))?;
    tbl.set("endpoint", get_endpoint())?;
    tbl.set("access_token_set", get_access_token().is_ok())?;

    tbl.to_lua(lua)
}

#[mlua::lua_module]
fn libsg_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set(
        "get_remote_file_contents",
        lua.create_function(get_remote_file_contents)?,
    )?;

    exports.set(
        "get_remote_directory_contents",
        lua.create_function(get_remote_directory_contents)?,
    )?;

    exports.set("get_entry", lua.create_function(lua_get_entry)?)?;
    exports.set("get_search", lua.create_function(get_search)?)?;

    exports.set("get_info", lua.create_function(get_info)?)?;

    Ok(exports)
}
