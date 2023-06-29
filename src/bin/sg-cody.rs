use {
    anyhow::Result,
    cody::*,
    serde::{Deserialize, Serialize},
    sg::{get_cody_completions, get_embeddings_context, get_repository_id},
    sg_types::*,
    std::{process::Stdio, thread, time::Duration},
    tokio::{
        io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
        process::{Child, Command},
        sync::broadcast::{Receiver, Sender},
        task::JoinHandle,
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

    ListRecipes {
        id: i32,
    },
}

impl Request {
    pub async fn respond(
        self,
        tx_cody: &Sender<Message>,
        rx_cody: &mut Receiver<Message>,
    ) -> Result<Response> {
        match self {
            Request::Echo { id, message, delay } => {
                if let Some(delay) = delay {
                    thread::sleep(Duration::from_secs(delay as u64));
                }

                Ok(Response::Echo { id, message })
            }
            Request::Complete { id, message } => {
                eprintln!("[sg-cody] complete: {id}");
                let completion = match get_cody_completions(message, None).await {
                    Ok(completion) => completion,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                    }
                };

                Ok(Response::Complete { id, completion })
            }
            Request::Repository { id, name } => {
                eprintln!("[sg-cody] repo: {id} {name}");
                let repository = match get_repository_id(name).await {
                    Ok(repo) => repo,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                    }
                };

                Ok(Response::Repository { id, repository })
            }
            Request::Embedding {
                id,
                repo,
                query,
                code,
                text,
            } => {
                eprintln!("[sg-cody] repo: {id} {repo}");
                let embeddings = match get_embeddings_context(repo, query, code, text).await {
                    Ok(embeddings) => embeddings,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                    }
                };

                Ok(Response::Embedding { id, embeddings })
            }
            Request::ListRecipes { id } => {
                eprintln!("[sg-cody] list recipes {id}");
                tx_cody.send(Message::new_request(RequestMethods::RecipesList))?;

                // TODO: I don't like that I can't be 100% sure that we're going to
                // get this response next... I'm a little worried about race conditions...
                // but oh well :)
                loop {
                    let msg = rx_cody.recv().await;
                    match msg {
                        Ok(Message::Response(cody::Response {
                            id,
                            result: ResponseTypes::Recipes(recipes),
                        })) => {
                            return Ok(Response::ListRecipes {
                                id: id as i32,
                                recipes,
                            })
                        }
                        _ => continue,
                    }
                }
            }
        }
    }
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "method")]
pub enum Response {
    Echo { id: i32, message: String },
    Complete { id: i32, completion: String },
    Repository { id: i32, repository: String },
    Embedding { id: i32, embeddings: Vec<Embedding> },
    ListRecipes { id: i32, recipes: Vec<RecipeInfo> },
}

fn spawn_neovim_loop(tx_cody: Sender<Message>, mut rx_cody: Receiver<Message>) -> JoinHandle<()> {
    tokio::spawn(async move {
        let stdin = tokio::io::stdin();
        let mut stdout = tokio::io::stdout();

        let reader = BufReader::new(stdin);
        let mut lines = reader.lines();

        while let Ok(Some(line)) = lines.next_line().await {
            eprintln!("LINE: {line:?}");
            let msg = serde_json::from_str::<Request>(&line);
            match msg {
                Ok(msg) => {
                    let response = match msg.respond(&tx_cody, &mut rx_cody).await {
                        Ok(msg) => msg,
                        Err(err) => {
                            eprintln!("{err:?}");
                            continue;
                        }
                    };

                    let msg = serde_json::to_string(&response).expect("to convert") + "\n";
                    stdout.write_all(msg.as_bytes()).await.expect("to write");
                    stdout.flush().await.expect("to flush");
                }
                Err(err) => {
                    eprintln!("[sg-cody] error, could not decode message: {err}");
                    continue;
                }
            };
        }
    })
}

fn spawn_cody_loop(
    write_to_agent: Sender<Message>,
    write_to_nvim: Sender<Message>,
    workspace_root: String,
) -> (JoinHandle<()>, JoinHandle<()>) {
    let child = Command::new("./dist/agent-linux-x64")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .expect("to spawn cody agent");

    let Child { stdin, stdout, .. } = child;

    let mut message_writer = write_to_agent.subscribe();
    let mut child_stdin = stdin.expect("told you so");
    let writer_task = tokio::spawn(async move {
        while let Ok(it) = message_writer.recv().await {
            eprintln!("-> {it:?}\n");
            write_msg(&mut child_stdin, it)
                .await
                .expect("to write message");
        }
    });

    let child_stdout = stdout.expect("told you so");
    let mut buffered_stdout = tokio::io::BufReader::new(child_stdout);
    let reader_task = tokio::spawn(async move {
        while let Some(msg) = Message::read(&mut buffered_stdout).await.expect("to read") {
            // let is_exit = matches!(&msg, Message::Notification(n) if n.is_exit());
            write_to_nvim.send(msg).expect("told you so");

            // if is_exit {
            //     break;
            // }
        }
    });

    // Initialize must be first message that is sent.
    let _ = write_to_agent.send(Message::initialize(workspace_root));

    // TODO: Send configuration

    (writer_task, reader_task)
}

#[tokio::main]
async fn main() -> Result<()> {
    let (write_to_agent, _) = tokio::sync::broadcast::channel::<Message>(32);
    let (write_to_nvim, _) = tokio::sync::broadcast::channel::<Message>(32);

    let (writer_task, reader_task) = spawn_cody_loop(
        write_to_agent.clone(),
        write_to_nvim.clone(),
        std::env::current_dir()
            .expect("to have a working directory")
            .to_str()
            .expect("to have a valid path")
            .to_string(),
    );

    let neovim_task = spawn_neovim_loop(write_to_agent.clone(), write_to_nvim.subscribe());

    let mut rx = write_to_nvim.subscribe();
    tokio::spawn(async move {
        loop {
            if let Ok(msg) = rx.try_recv() {
                eprintln!("<- {msg:?}");
            }
        }
    });

    // Request the recipe list
    let _ = write_to_agent.send(Message::new_request(RequestMethods::RecipesList));

    // Execute a recipe
    // write_to_agent.send(Message::new_request(RequestMethods::RecipesExecute {
    //     id: "chat-question".to_string(),
    //     human_chat_input: "Say hello and write a haiku about ocaml".to_string(),
    // }));

    let _ = tokio::join!(writer_task, reader_task, neovim_task);

    Ok(())
}
