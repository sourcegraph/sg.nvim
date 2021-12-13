// use once_cell::sync::OnceCell;

use std::sync::Arc;
use std::sync::Mutex;

use interprocess::local_socket::LocalSocketStream;
use mlua::prelude::*;
use mlua::Function;
use mlua::LuaSerdeExt;
use mlua::SerializeOptions;
use mlua::Value;
use reqwest;
use serde::Serialize;
use sg;
use sg::files;
use sg::ContentsMessage;
use sg::GetFilesMessage;
use sg::HashMessage;
use sg::RemoteFileMessage;
use sg::RemoteMessage;

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

fn get_remote_file_content<'lua>(lua: &'lua Lua, args: (String, String, String)) -> LuaResult<LuaValue<'lua>> {
    ContentsMessage {
        remote: args.0,
        hash: args.1,
        path: args.2,
    }
    .request(lua)
}

fn get_remote_file<'lua>(lua: &'lua Lua, args: (String,)) -> LuaResult<LuaValue<'lua>> {
    RemoteFileMessage { path: args.0 }.request(lua)
}

fn get_files<'lua>(lua: &'lua Lua, args: (String, String)) -> LuaResult<LuaValue<'lua>> {
    let mut file_map = files::get_file_map().lock().unwrap();

    let repository = args.0;
    let commit = args.1;

    let key = (repository.clone(), commit.clone());

    if let None = file_map.get(&key) {
        // info!("MISSING KEY! {:?}", key);
        lua_print(lua, "Missing Key!")?;

        let mut conn = LocalSocketStream::connect("/tmp/example.sock")?;
        let response = GetFilesMessage {
            repository: repository.clone(),
            commit: commit.clone(),
        }
        .get_response(&mut conn)
        .unwrap();

        file_map.insert(
            (repository, commit),
            response
                .as_array()
                .expect("needs array")
                .into_iter()
                .map(|x| x.as_str().expect("all strings").to_string())
                .collect(),
        );
    } else {
        lua_print(lua, "ACTUALLY HAD THE KEY")?;
    }

    if let Some(result) = file_map.get(&key) {
        return result
            .into_iter()
            .map(|x| x.clone().to_lua(lua).unwrap())
            .collect::<Vec<LuaValue>>()
            .to_lua(lua);
    } else {
        panic!("Cannot not have something now...");
    }
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
    exports.set("get_files", lua.create_function(get_files)?)?;

    // TODO: Understand this at some point would be good.
    exports.set(
        "docs",
        lua.create_function(|lua, func: Function| {
            let rt = tokio::runtime::Runtime::new().to_lua_err()?;
            rt.block_on(async {
                let lua: &'static Lua = unsafe { std::mem::transmute(lua) };
                let tasks = Arc::new(Mutex::new(Vec::new()));
                let tasks2 = tasks.clone();

                let get = lua.create_function(move |_, (uri, cb): (String, Function)| {
                    let mut inner_tasks = tasks2.lock().unwrap();
                    inner_tasks.push(tokio::task::spawn_local(async move {
                        let res = reqwest::get(&uri).await.and_then(|r| r.error_for_status());
                        let body = res.to_lua_err()?.text().await.to_lua_err()?;
                        cb.call::<_, ()>(body)
                    }));
                    Ok(())
                })?;

                let local = tokio::task::LocalSet::new();
                local
                    .run_until(async move {
                        func.call(get)?;
                        futures::future::join_all(&mut *tasks.lock().unwrap()).await;
                        Ok(())
                    })
                    .await
            })
        })?,
    )?;

    Ok(exports)
}
