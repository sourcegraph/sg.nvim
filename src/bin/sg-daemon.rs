extern crate rmp;

use {
    interprocess::local_socket::{LocalSocketListener, LocalSocketStream},
    rmpv,
    sg::{ContentsMessage, HashMessage, RemoteFileMessage, RemoteMessage, DAEMON_SOCKET},
    std::{error::Error, io},
};

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
    let listener = LocalSocketListener::bind(DAEMON_SOCKET)?;

    for mut conn in listener.incoming().filter_map(handle_error) {
        println!("Getting new connect...");

        match rmpv::decode::read_value(&mut conn)? {
            arr @ rmpv::Value::Array(_) => {
                println!("");
                println!("DaemonRead: {:?}", arr);

                let command = arr[0].as_str().unwrap();
                // match command {
                //   HashMessage::NAME => {
                //     println!("Handling: {:?}", HashMessage::NAME);
                //     let res = HashMessage::handle(&mut conn, arr).await?;
                //     println!("Complete: {:?} {:?}", HashMessage::NAME, res);
                //   }
                //   ContentsMessage::NAME => {
                //     println!("Handling: {:?}", ContentsMessage::NAME);
                //     let res = ContentsMessage::handle(&mut conn, arr).await?;
                //     println!("Complete: {:?} {:?}", ContentsMessage::NAME, res);
                //   }
                // }
                match_messages!(
                    conn,
                    arr,
                    command,
                    [HashMessage, ContentsMessage, RemoteFileMessage]
                );
            }

            _ => {
                panic!("Did not even get an array.. that's really bad :'(");
            }
        };
    }

    Ok(())
}
