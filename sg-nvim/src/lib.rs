use std::sync::Arc;
use std::sync::Mutex;

use interprocess::local_socket::LocalSocketStream;
use mlua::prelude::*;
use mlua::Function;
use mlua::LuaSerdeExt;
use mlua::SerializeOptions;
use mlua::Value;
use once_cell::sync::OnceCell;
use reqwest;
use serde::Serialize;
use sg;
use sg::ContentsMessage;
use sg::HashMessage;
use sg::RemoteMessage;
use tokio::runtime::Runtime;

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

fn get_runtime() -> &'static Runtime {
  static INSTANCE: OnceCell<Runtime> = OnceCell::new();
  INSTANCE.get_or_init(|| Runtime::new().unwrap())
}

fn lua_print(lua: &Lua, str: &str) -> LuaResult<()> {
  let print: Function = lua.globals().get("print")?;
  print.call::<_, ()>(str.to_lua(lua))?;

  Ok(())
}

async fn get_remote_contents<'lua>(lua: &'lua Lua, args: (String, String, String)) -> LuaResult<LuaValue<'lua>> {
  lua_print(lua, "Checking remote file")?;
  // lua_print(lua, &format!("WHAT IS THIS: {:?}", user_data).to_string())?;
  // let remote_file: sg::RemoteFile = lua.from_value(mlua::Value::UserData(user_data))?;
  // lua.from_value(remote_file)?;
  // lua_print(lua, "After remote file")?;

  match sg::get_remote_file_contents(&args.0, &args.1, &args.2).await {
    Ok(data) => to_lua(lua, &data),
    Err(_) => Ok(LuaNil),
  }
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

// macro_rules! set_luafunc {
//   // Convert any async func that does normal lua things into a sync func we can call
//   // and use the shared runtime
//   ($lua: ident, $exports: ident, $key: literal, $async_func: ident) => {
//     $exports.set(
//       $key,
//       $lua.create_function(|lua, param| get_runtime().block_on($async_func(lua, param)))?,
//     )?;
//   };
// }

#[mlua::lua_module]
fn libsg_nvim(lua: &Lua) -> LuaResult<LuaTable> {
  // TODO: Consider putting mlua_null as a global so we can compare with that
  // Patatas_del_papa: I was going to ask if doing something like lua.globals().set("null", lua.null())? could be the solution

  let exports = lua.create_table()?;

  // set_luafunc!(lua, exports, "get_remote_file", get_remote_file);
  // set_luafunc!(lua, exports, "get_remote_contents", get_remote_contents);

  exports.set(
    "get_remote_hash",
    lua.create_function(|lua, param| get_remote_hash(lua, param))?,
  )?;

  exports.set(
    "get_remote_file_contents",
    lua.create_function(|lua, param| get_remote_file_content(lua, param))?,
  )?;

  exports.set(
    "get_remote_contents",
    lua.create_function(|lua, param| get_runtime().block_on(get_remote_contents(lua, param)))?,
  )?;

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

#[cfg(test)]
mod tests {
  #[test]
  fn it_works() {
    let result = 2 + 2;
    assert_eq!(result, 4);
  }
}
