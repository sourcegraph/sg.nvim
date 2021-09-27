extern crate rmp;

use std::error::Error;
use std::io;

use interprocess::local_socket::LocalSocketListener;
use interprocess::local_socket::LocalSocketStream;
use rmpv;

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
          "hash" => {
            let hash = sg::get_commit_hash(
              arr[1].as_str().unwrap().to_string(),
              arr[2].as_str().unwrap().to_string(),
            )
            .await?;

            let val = rmpv::Value::Array(vec![hash.into()]);

            rmpv::encode::write_value(&mut conn, &val)?;
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
