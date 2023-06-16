use {
    anyhow::Result,
    serde::{Deserialize, Serialize},
    sg::cody::get_completions,
    std::{
        io::{stdin, Write},
        thread,
        time::Duration,
    },
};

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "method")]
pub enum Request {
    Echo {
        id: i32,
        message: String,
        delay: Option<i32>,
    },

    Complete {
        id: i32,
        message: String,
    },
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "method")]
pub enum Response {
    Echo { id: i32, message: String },
    Complete { id: i32, completion: String },
}

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = stdin();
    let mut stdout = std::io::stdout();

    for line in stdin.lines() {
        eprintln!("[sg-cody] parsing line");
        let line = match line {
            Ok(line) => line,
            Err(err) => {
                eprintln!("[sg-cody] failed to get a line: {err:?}");
                continue;
            }
        };

        eprintln!("[sg-cody] got a line {line}");
        let msg = serde_json::from_str::<Request>(&line);
        eprintln!("[sg-cody] done reading request");

        match msg {
            Ok(msg) => {
                eprintln!("[sg-cody] got a request");

                let response = match msg {
                    Request::Echo { id, message, delay } => {
                        if let Some(delay) = delay {
                            thread::sleep(Duration::from_secs(delay as u64));
                        }

                        Response::Echo { id, message }
                    }
                    Request::Complete { id, message } => {
                        eprintln!("complete: {id} {message}");
                        let completion = match get_completions(message, None).await {
                            Ok(completion) => completion,
                            Err(err) => {
                                eprintln!("failed to get completions: {err:?}");
                                continue;
                            }
                        };

                        Response::Complete { id, completion }
                    }
                };

                let msg = serde_json::to_string(&response)? + "\n";
                stdout.write_all(msg.as_bytes())?;
                stdout.flush()?;
            }
            Err(err) => {
                eprintln!("error, could not decode: {err}");
                continue;
            }
        };
    }

    Ok(())
}
