// use once_cell::sync::OnceCell;
#![allow(unused)]

use {
    mlua::{prelude::*, Function, LuaSerdeExt, SerializeOptions, Value},
    nvim_oxi::{self as oxi, Dictionary},
    once_cell::sync::OnceCell,
    oxi::{libuv::AsyncHandle, print, Object},
    serde::Serialize,
    sg::{self, entry::Entry, get_access_token, get_endpoint, get_sourcegraph_version, search},
    std::thread,
    tokio::sync::{
        mpsc,
        mpsc::{UnboundedReceiver, UnboundedSender},
    },
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

fn get_remote_file_contents(args: (String, String, String)) -> oxi::Result<Vec<String>> {
    let remote = args.0;
    let hash = args.1;
    let path = args.2;

    let rt = tokio::runtime::Runtime::new().to_lua_err().unwrap();
    let remote_file = rt
        .block_on(async { sg::maybe_read_stuff(&remote, &hash, &path).await })
        .to_lua_err()
        .unwrap();

    Ok(remote_file
        .split('\n')
        .map(|s| s.to_string())
        .collect::<Vec<String>>())
}

// fn get_remote_directory_contents(
//     (remote, hash, path): (String, String, String),
// ) -> oxi::Result<LuaValue> {
//     let rt = tokio::runtime::Runtime::new().to_lua_err()?;
//     let directory_contents = rt
//         .block_on(async {
//             sg::get_remote_directory_contents(&remote, &hash, &path)
//                 .await
//                 .map(|v| {
//                     v.into_iter()
//                         .filter_map(|e| Entry::from_info(e).ok())
//                         .collect::<Vec<_>>()
//                 })
//         })
//         .to_lua_err()?;
//
//     directory_contents.to_lua(lua)
// }

fn get_search(lua: &Lua, args: (String,)) -> LuaResult<LuaValue> {
    let path = args.0;
    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    let search_results = rt
        .block_on(async { search::get_search(path.as_str()).await })
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

type Data = i32;
type Message = (Data, tokio::sync::oneshot::Sender<i32>);

fn start_server() -> &'static UnboundedSender<Message> {
    static CELL: OnceCell<UnboundedSender<Message>> = OnceCell::new();
    CELL.get_or_init(|| {
        let (sender, receiver) = mpsc::unbounded_channel::<Message>();
        let _ = thread::spawn(|| handle_requests(receiver));
        sender
    })
}

fn send_request((id, method): (i32, oxi::String)) -> oxi::Result<()> {
    print!("Received number {id} outside callback for {method:?}");

    let sender = start_server();
    let (tx, mut rx) = tokio::sync::oneshot::channel();
    sender.send((1, tx)).expect("to send this");

    let handle = AsyncHandle::new(move || {
        let i = rx.try_recv().expect("i");
        oxi::schedule(move |_| {
            print!("Received number {i} from backround thread");
            Ok(())
        });
        Ok::<_, oxi::Error>(())
    })?;

    // let handle = AsyncHandle::new(async move {
    //     Ok(())
    // });

    Ok(())
}

async fn handle_requests(mut handle: UnboundedReceiver<Message>) {
    loop {
        if let Some((num, sender)) = handle.recv().await {
            sender.send(num).expect("to send this stuff")
        }
    }
}

fn get_completions(lua: &Lua, (text, temp): (String, Option<f64>)) -> LuaResult<LuaValue> {
    let rt = tokio::runtime::Runtime::new().to_lua_err()?;
    rt.block_on(async { sg::cody::get_completions(text, temp).await })
        .to_lua_err()?
        .to_lua(lua)
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
        Entry::Repo(_) => todo!("repo: not yet implemented"),
    }
    .to_lua(lua)
}

#[oxi::module]
fn libsg_nvim() -> oxi::Result<Dictionary> {
    Ok(Dictionary::from_iter([
        (
            "get_remote_file_contents",
            Object::from(oxi::Function::from_fn(get_remote_file_contents)),
        ),
        (
            "send_request",
            Object::from(oxi::Function::from_fn(send_request)),
        ),
    ]))
}

// fn _something(lua: &Lua) -> LuaResult<LuaTable> {
//     let exports = lua.create_table()?;
//
//     exports.set(
//         "get_remote_file_contents",
//         lua.create_function(get_remote_file_contents)?,
//     )?;
//
//     exports.set(
//         "get_remote_directory_contents",
//         lua.create_function(get_remote_directory_contents)?,
//     )?;
//
//     exports.set("get_entry", lua.create_function(lua_get_entry)?)?;
//     exports.set("get_search", lua.create_function(get_search)?)?;
//     exports.set("get_info", lua.create_function(get_info)?)?;
//     exports.set("get_link", lua.create_function(get_link)?)?;
//
//     exports.set("get_completions", lua.create_function(get_completions)?)?;
//
//     exports.set(
//         "testing",
//         lua.create_function(|lua, (cb,): (LuaFunction,)| {
//             // let cb = Box::new(cb);
//             // lua.scope(f)
//             // thread::spawn(move || {
//             //     let x = cb.call::<_, u32>((3, 4)).unwrap();
//             //     println!("x: {}", x);
//             // });
//
//             let x = cb.call::<_, u32>((3, 4))?;
//             x.to_lua(lua)
//         })?,
//     )?;
//
//     // #[tokio::main]
//     // async fn main() -> Result<()> {
//     //     let lua = Lua::new();
//     //     lua.globals().set("sleep", lua.create_async_function(sleep)?)?;
//     //     let res: String = lua.load("return sleep(...)").call_async(100).await?; // Sleep 100ms
//     //     assert_eq!(res, "done");
//     //     Ok(())
//     // }
//     // tokio::spawn(async move {
//     //     let x = sg::cody::get_completions(text, temp).await.unwrap();
//     //     // lua.call(cb, x)
//     //     cb.call((x,));
//     // });
//     //
//     // lua.create_string("ok")?.to_lua(lua);
//
//     Ok(exports)
// }
