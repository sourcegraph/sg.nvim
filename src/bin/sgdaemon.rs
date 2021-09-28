extern crate rmp;

use std::error::Error;
use std::io;

use interprocess::local_socket::LocalSocketListener;
use interprocess::local_socket::LocalSocketStream;
use rmpv;
use sg::ContentsMessage;
use sg::HashMessage;
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

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
  let listener = LocalSocketListener::bind("/tmp/example.sock")?;

  for mut conn in listener.incoming().filter_map(handle_error) {
    println!("Getting new connect...");

    match rmpv::decode::read_value(&mut conn)? {
      rmpv::Value::Array(arr) => {
        println!("Got an array... {:?}", arr);

        if arr.is_empty() {
          println!("... Dude, don't send empty arrays");
          continue;
        }

        let command = arr[0].as_str().unwrap();
        match command {
          HashMessage::NAME => {
            println!("Handling HashMessage");
            let message = HashMessage::decode(arr);
            let hash = sg::get_commit_hash(message.remote.clone(), message.hash.clone()).await?;
            message.respond(&mut conn, vec![hash.into()])?;
          }

          ContentsMessage::NAME => {
            println!("Handling ContentsMessage");
            let message = ContentsMessage::decode(arr);
            let contents = sg::get_remote_file_contents(&message.remote, &message.hash, &message.path).await?;
            // println!("... {:?} ...", contents);
            message.respond(&mut conn, contents.into_iter().map(|x| x.clone().into()).collect())?;
          }

          _ => {
            continue;
          }
        }
      }

      _ => {
        println!("Bad bad bad...");
        continue;
      }
    };

    println!("...Processed");
  }

  Ok(())
}
