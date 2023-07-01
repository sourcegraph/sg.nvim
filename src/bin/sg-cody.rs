use {
    anyhow::Result,
    std::{process::Stdio, sync::Arc},
    tokio::{
        io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
        process::{Child, Command},
        sync::{
            broadcast::{Receiver, Sender},
            Mutex,
        },
        task::JoinHandle,
    },
};

fn spawn_neovim_loop(
    tx_cody: Sender<cody::Message>,
    mut rx_cody: Receiver<cody::Message>,
    mut notify_nvim: Receiver<nvim::Message>,
) -> JoinHandle<()> {
    let stdin = tokio::io::stdin();
    let stdout = Arc::new(Mutex::new(tokio::io::stdout()));

    let reader = BufReader::new(stdin);
    let mut lines = reader.lines();

    let notify_stdout = stdout.clone();
    tokio::spawn(async move {
        loop {
            match notify_nvim.recv().await {
                Ok(msg) => {
                    // For now, only send notifications
                    if let nvim::Message::Notification(nvim::Notification::Hack { json }) = msg {
                        let mut stdout = notify_stdout.lock().await;

                        // AHHHH need to write functions instead
                        let json = json + "\n";

                        stdout.write_all(json.as_bytes()).await.expect("to write");
                        stdout.flush().await.expect("to flush");
                    }
                }
                Err(err) => eprintln!("error in notification loop: {err:?}"),
            };
        }
    });

    let request_stdout = stdout;
    tokio::spawn(async move {
        while let Ok(Some(line)) = lines.next_line().await {
            eprintln!("cody reading line: {line:?}");
            let msg = serde_json::from_str::<nvim::Request>(&line);
            match msg {
                Ok(msg) => {
                    let response = match msg.respond(&tx_cody, &mut rx_cody).await {
                        Ok(msg) => msg,
                        Err(err) => {
                            eprintln!("{err:?}");
                            continue;
                        }
                    };

                    let mut stdout = request_stdout.lock().await;

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
    write_to_agent: Sender<cody::Message>,
    write_to_nvim: Sender<cody::Message>,
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
            cody::write_msg(&mut child_stdin, it)
                .await
                .expect("to write message");
        }
    });

    let child_stdout = stdout.expect("told you so");
    let mut buffered_stdout = tokio::io::BufReader::new(child_stdout);
    let reader_task = tokio::spawn(async move {
        while let Some(msg) = cody::Message::read(&mut buffered_stdout)
            .await
            .expect("to read")
        {
            // let is_exit = matches!(&msg, Message::Notification(n) if n.is_exit());
            write_to_nvim.send(msg).expect("told you so");

            // if is_exit {
            //     break;
            // }
        }
    });

    // Initialize must be first message that is sent.
    let _ = write_to_agent.send(cody::Message::initialize(workspace_root));

    // TODO: Send configuration

    (writer_task, reader_task)
}

#[tokio::main]
async fn main() -> Result<()> {
    let (write_to_agent, _) = tokio::sync::broadcast::channel::<cody::Message>(32);
    let (write_to_nvim, _) = tokio::sync::broadcast::channel::<cody::Message>(32);
    let (write_nvim_message, read_nvim_message) =
        tokio::sync::broadcast::channel::<nvim::Message>(32);

    // let (write_nvim_message, read_nvim_message) =
    //     tokio::sync::mpsc::unbounded_channel::<nvim::Message>();

    let (writer_task, reader_task) = spawn_cody_loop(
        write_to_agent.clone(),
        write_to_nvim.clone(),
        std::env::current_dir()
            .expect("to have a working directory")
            .to_str()
            .expect("to have a valid path")
            .to_string(),
    );

    let neovim_task = spawn_neovim_loop(
        write_to_agent.clone(),
        write_to_nvim.subscribe(),
        read_nvim_message,
    );

    let mut rx = write_to_nvim.subscribe();
    tokio::spawn(async move {
        loop {
            if let Ok(msg) = rx.try_recv() {
                eprintln!("<- {msg:?}");
                match msg {
                    cody::Message::Notification(notification) => {
                        let msg = serde_json::to_string(&notification).expect("to convert to json");

                        eprintln!("sending notification: {msg:?}");
                        write_nvim_message
                            .send(nvim::Message::Notification(nvim::Notification::Hack {
                                json: msg,
                            }))
                            .expect("to write to nvim");
                        eprintln!("wrote to nvim");
                    }
                    cody::Message::Request(_) => {}
                    cody::Message::Response(_) => {}
                }
            }
        }
    });

    // Request the recipe list
    let _ = write_to_agent.send(cody::Message::new_request(
        cody::RequestMethods::RecipesList,
    ));

    // Execute a recipe
    // write_to_agent.send(Message::new_request(RequestMethods::RecipesExecute {
    //     id: "chat-question".to_string(),
    //     human_chat_input: "Say hello and write a haiku about ocaml".to_string(),
    // }));

    let _ = tokio::join!(writer_task, reader_task, neovim_task);

    Ok(())
}
