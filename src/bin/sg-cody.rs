use {
    anyhow::Result,
    serde::{Deserialize, Serialize},
    sg::{cody::get_completions, get_embeddings_context, get_repo, Embedding},
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

    Repository {
        id: i32,
        name: String,
    },

    Embedding {
        id: i32,
        repo: String,
        query: String,
        code: i64,
        text: i64,
    },
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "method")]
pub enum Response {
    Echo { id: i32, message: String },
    Complete { id: i32, completion: String },
    Repository { id: i32, repository: String },
    Embedding { id: i32, embeddings: Vec<Embedding> },
}

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = stdin();
    let mut stdout = std::io::stdout();

    for line in stdin.lines() {
        let line = match line {
            Ok(line) => line,
            Err(err) => {
                eprintln!("[sg-cody] failed to get a line: {err:?}");
                continue;
            }
        };

        let msg = serde_json::from_str::<Request>(&line);
        match msg {
            Ok(msg) => {
                let response = match msg {
                    Request::Echo { id, message, delay } => {
                        if let Some(delay) = delay {
                            thread::sleep(Duration::from_secs(delay as u64));
                        }

                        Response::Echo { id, message }
                    }
                    Request::Complete { id, message } => {
                        eprintln!("[sg-cody] complete: {id}");
                        let completion = match get_completions(message, None).await {
                            Ok(completion) => completion,
                            Err(err) => {
                                eprintln!("failed to get completions: {err:?}");
                                continue;
                            }
                        };

                        Response::Complete { id, completion }
                    }
                    Request::Repository { id, name } => {
                        eprintln!("[sg-cody] repo: {id} {name}");
                        let repository = match get_repo(name).await {
                            Ok(repo) => repo,
                            Err(err) => {
                                eprintln!("failed to get completions: {err:?}");
                                continue;
                            }
                        };

                        Response::Repository { id, repository }
                    }
                    Request::Embedding {
                        id,
                        repo,
                        query,
                        code,
                        text,
                    } => {
                        eprintln!("[sg-cody] repo: {id} {repo}");
                        let embeddings = match get_embeddings_context(repo, query, code, text).await
                        {
                            Ok(embeddings) => embeddings,
                            Err(err) => {
                                eprintln!("failed to get completions: {err:?}");
                                continue;
                            }
                        };

                        Response::Embedding { id, embeddings }
                    }
                };

                let msg = serde_json::to_string(&response)? + "\n";
                stdout.write_all(msg.as_bytes())?;
                stdout.flush()?;
            }
            Err(err) => {
                eprintln!("[sg-cody] error, could not decode message: {err}");
                continue;
            }
        };
    }

    Ok(())
}
