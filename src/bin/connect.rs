extern crate rmp;

use std::env;
use std::error::Error;

// use std::io::prelude::*;
// use std::io::BufReader;
use interprocess::local_socket::LocalSocketStream;
use rmpv;

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();
    let mut conn = LocalSocketStream::connect("/tmp/example.sock")?;

    // TODO: I don't know if this should be a bunch more complicated??
    match args[1].as_str() {
        "hash" => {
            println!("Getting the hash...");

            let val = rmpv::Value::Array(vec!["hash".into(), args[2].clone().into(), args[3].clone().into()]);

            // Send request
            rmpv::encode::write_value(&mut conn, &val)?;

            // Read response
            match rmpv::decode::read_value(&mut conn)? {
                rmpv::Value::Array(response) => {
                    println!("Hash: {}", response[0]);
                }

                _ => {
                    println!("Actually should handle this...");
                    return Ok(());
                }
            }

            return Ok(());
        }
        _ => {}
    };

    Ok(())
}
