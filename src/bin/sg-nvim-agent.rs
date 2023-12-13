use {
    anyhow::Result,
    jsonrpc::RPCErr,
    reqwest::Url,
    sg::{
        auth::{get_access_token, get_endpoint},
        nvim::{self, NeovimTasks, Notification},
    },
    std::sync::Arc,
    tokio::{io::BufReader, sync::Mutex, task::JoinHandle},
};

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = tokio::io::stdin();
    let mut reader = BufReader::new(stdin);
    let stdout = Arc::new(Mutex::new(tokio::io::stdout()));

    // Initialize by letting neovim know if we have a saved token or not
    eprintln!("Writing initialize notification...");
    let wrote = jsonrpc::write_msg(
        &stdout,
        nvim::Message::notification(Notification::Initialize {
            endpoint: Some(get_endpoint()),
            token: get_access_token(),
        }),
    )
    .await;
    eprintln!("WROTE: {:?}", wrote);
    eprintln!(">> Done initialize notification...");

    let rpc_stdout = stdout.clone();

    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    let rpc: JoinHandle<Result<()>> = tokio::spawn(async move {
        let stdout = rpc_stdout;

        loop {
            let message: Result<Option<nvim::Message>> = jsonrpc::read_msg(&mut reader).await;
            match message {
                Ok(Some(nvim::Message::Request(message))) => {
                    eprintln!("Recieved a message: {message:?}");
                    let sent = match message.respond(&tx).await {
                        Ok(response) => jsonrpc::write_msg(&stdout, response).await,
                        Err(err) => {
                            jsonrpc::write_err(
                                &stdout,
                                RPCErr {
                                    code: 1,
                                    message: err.to_string(),
                                },
                            )
                            .await
                        }
                    };

                    if sent.is_err() {
                        return Err(anyhow::anyhow!("Failed to send response, must be closed"));
                    }
                }
                Ok(Some(message)) => {
                    eprintln!("Somehow got a not request: {message:?}");
                }
                Ok(None) => eprintln!("neovim exited unexpectedly?"),
                Err(err) => eprintln!("[sg-nvim-agent] failed to read message {err:?}"),
            }
        }
    });

    let notifications: JoinHandle<Result<()>> = tokio::spawn(async move {
        while let Some(task) = rx.recv().await {
            match task {
                NeovimTasks::Authentication { port } => {
                    std::thread::spawn(move || {
                        let server = tiny_http::Server::http(format!("127.0.0.1:{port}")).unwrap();
                        let request = server.recv().expect("to launch request");

                        // Create url to parse the parameters, a bit goofy but it is what it is
                        let url = format!("http://127.0.0.1:{}{}", port, request.url());
                        let url = Url::parse(&url).expect("to parse URL");

                        if let Some((_, token)) = url.query_pairs().find(|(k, _)| k == "token") {
                            let response = tiny_http::Response::from_string(
                                "Credentials have been saved to Neovim. Restart Neovim now.",
                            );

                            // Ignore response errors
                            let _ = request.respond(response);

                            sg::auth::set_credentials(sg::auth::CodyCredentials {
                                endpoint: Some("https://sourcegraph.com/".to_string()),
                                token: Some(token.to_string()),
                            })
                            .expect("to set credentials");
                        }
                    });
                }
            }
        }

        Ok(())
    });

    let _ = tokio::try_join!(rpc, notifications)?;

    Ok(())
}
