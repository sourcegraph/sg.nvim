use {anyhow::Result, jsonrpc::RPCErr, sg::nvim, tokio::io::BufReader};

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = tokio::io::stdin();
    let mut reader = BufReader::new(stdin);

    loop {
        let message: Result<Option<nvim::Message>> = jsonrpc::read_msg(&mut reader).await;
        match message {
            Ok(Some(nvim::Message::Request(message))) => {
                // got some messages
                eprintln!("Recieved a message: {message:?}");
                match message.respond().await {
                    Ok(response) => jsonrpc::write_msg(&mut stdout, response).await?,
                    Err(err) => {
                        jsonrpc::write_err(
                            &mut stdout,
                            RPCErr {
                                code: 1,
                                message: err.to_string(),
                            },
                        )
                        .await?
                    }
                };
            }
            Ok(Some(message)) => {
                eprintln!("Somehow got a not request: {message:?}");
            }
            Ok(None) => eprintln!("neovim exited unexpectedly?"),
            Err(err) => eprintln!("[sg-nvim-agent] failed to read message {err:?}"),
        }
    }
}
