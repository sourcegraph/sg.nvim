use {anyhow::Result, tokio::io::BufReader};

#[tokio::main]
async fn main() -> Result<()> {
    let stdin = tokio::io::stdin();
    let mut reader = BufReader::new(stdin);

    let mut stdout = tokio::io::stdout();

    loop {
        let message: Result<Option<nvim::Message>> = jsonrpc::read_msg(&mut reader).await;
        match message {
            Ok(Some(nvim::Message::Request(message))) => {
                // got some messages
                eprintln!("Recieved a message: {message:?}");
                let _ = jsonrpc::write_msg(&mut stdout, message.respond().await?).await;
            }
            Ok(Some(message)) => {
                eprintln!("Somehow got a not request: {message:?}");
            }
            Ok(None) => eprintln!("neovim exited unexpectedly?"),
            Err(err) => eprintln!("[sg-lib] failed to read message {err:?}"),
        }
    }
}
