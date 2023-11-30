use {
    anyhow::Result,
    jsonrpc::RPCErr,
    sg::{
        nvim,
        nvim::{NeovimTasks, Notification},
    },
    std::sync::Arc,
    tokio::{io::BufReader, sync::Mutex, task::JoinHandle},
};

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = tokio::io::stdin();
    let mut reader = BufReader::new(stdin);
    let stdout = Arc::new(Mutex::new(tokio::io::stdout()));

    let rpc_stdout = stdout.clone();

    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    let rpc: JoinHandle<Result<()>> = tokio::spawn(async move {
        let stdout = rpc_stdout;

        loop {
            let message: Result<Option<nvim::Message>> = jsonrpc::read_msg(&mut reader).await;
            match message {
                Ok(Some(nvim::Message::Request(message))) => {
                    // got some messages
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
        let stdout = stdout.clone();

        // .auth/github/login?pc=https%3A%2F%2Fgithub.com%2F%3A%3Ae917b2b7fa9040e1edd4
        //  &redirect=/post-sign-up?returnTo=/user/settings/tokens/new/callback?requestFrom=JETBRAINS-$port"

        // TODO: If we have some more, we'll need to do a bit more...
        while let Some(NeovimTasks::Authentication) = rx.recv().await {
            // Save test token
            sg::auth::set_cody_access_token("testing token".to_string()).await?;

            let _ = jsonrpc::write_msg(
                &stdout,
                Notification::DisplayText {
                    message: "WOW".to_string(),
                },
            )
            .await;
        }

        Ok(())
    });

    let _ = tokio::try_join!(rpc, notifications)?;

    Ok(())
}
