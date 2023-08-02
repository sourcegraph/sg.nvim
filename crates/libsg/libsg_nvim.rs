// use once_cell::sync::OnceCell;

use {
    mlua::{prelude::*, Function, LuaSerdeExt, SerializeOptions, Value},
    serde::Serialize,
    sg::{self, entry::Entry, get_access_token, get_endpoint, get_sourcegraph_version},
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
        .block_on(async { sg::get_file_contents(&remote, &hash, &path).await })
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
                        .filter_map(|e| Entry::from_info(e).ok())
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
        .block_on(async { sg::get_search(path).await })
        .to_lua_err()?;

    // TODO: We kind of silently skip the ones that fail here...
    // which seems a bit weird. I do wonder what I should be doing with that
    //
    // I don't think they can really fail because it's just setting values
    // in lua... so if this fails, we are kinda in trouble.
    search_results
        .into_iter()
        .filter_map(|res| {
            let mapped = lua.create_table().ok()?;
            mapped.set("repo", res.repo).ok()?;
            mapped.set("file", res.file).ok()?;
            mapped.set("preview", res.preview).ok()?;
            mapped.set("line", res.line).ok()?;
            Some(mapped)
        })
        .collect::<Vec<_>>()
        .to_lua(lua)
}

fn lua_get_entry(lua: &Lua, args: (String,)) -> LuaResult<LuaValue> {
    let path = args.0;

    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let search_results = rt
        .block_on(async { Entry::new(&path).await })
        .to_lua_err()?;

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
    tbl.set("access_token_set", !get_access_token().is_empty())?;

    tbl.to_lua(lua)
}

fn get_link(lua: &Lua, (bufname, line, col): (String, usize, usize)) -> LuaResult<LuaValue> {
    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    match rt
        .block_on(async { Entry::new(&bufname).await })
        .to_lua_err()?
    {
        Entry::File(file) => {
            let endpoint = get_endpoint();
            let remote = file.remote.0;
            let path = file.path;

            format!("{endpoint}/{remote}/-/blob/{path}?L{line}:{col}")
        }
        Entry::Directory(dir) => {
            let endpoint = get_endpoint();
            let remote = dir.remote.0;
            let path = dir.path;

            format!("{endpoint}/{remote}/-/tree/{path}")
        }
        Entry::Repo(repo) => {
            let endpoint = get_endpoint();
            let remote = repo.remote.0;
            let oid = repo.oid.0;

            format!("{endpoint}/{remote}@{oid}")
        }
    }
    .to_lua(lua)
}

#[mlua::lua_module]
fn libsg_nvim(lua: &Lua) -> LuaResult<LuaTable> {
    let _ = get_access_token();
    let _ = get_endpoint();

    let exports = lua.create_table()?;

    exports.set(
        "get_remote_file_contents",
        lua.create_function(get_remote_file_contents)?,
    )?;

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
    exports.set("get_link", lua.create_function(get_link)?)?;

    Ok(exports)
}
