extern crate rmp;

use std::error::Error;
use std::io;

use interprocess::local_socket::LocalSocketListener;
use interprocess::local_socket::LocalSocketStream;
use rmpv;
use sg::ContentsMessage;
use sg::GetFilesMessage;
use sg::HashMessage;
use sg::RemoteFileMessage;
use sg::RemoteMessage;

fn handle_error(conn: io::Result<LocalSocketStream>) -> Option<LocalSocketStream> {
    match conn {
        Ok(val) => Some(val),
        Err(error) => {
            eprintln!("Incoming connection failed: {}", error);
            None
        }
    }
}

macro_rules! match_messages {
  ($conn: ident, $arr: ident, $command:ident, [ $($typ: tt),* ]) => {
    match $command {
      $($typ::NAME => {
          println!("Handling: {:?}", $typ::NAME);
          let res = $typ::handle(&mut $conn, $arr).await?;
          println!("Complete: {:?} {:?}", $typ::NAME, res);
      },)*
      _ => panic!("Unknown command: {:?}", $command),
    }
  };
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let listener = LocalSocketListener::bind("/tmp/example.sock")?;

    for mut conn in listener.incoming().filter_map(handle_error) {
        println!("");
        println!("Getting new connect...");

        match rmpv::decode::read_value(&mut conn)? {
            arr @ rmpv::Value::Array(_) => {
                println!("DaemonRead: {:?}", arr);

                let command = arr[0].as_str().unwrap();
                match_messages!(
                    conn,
                    arr,
                    command,
                    [HashMessage, ContentsMessage, RemoteFileMessage, GetFilesMessage]
                );
            }

            _ => {
                drop(listener);
                panic!("Did not even get an array.. that's really bad :'(");
            }
        };
    }

    Ok(())
}
