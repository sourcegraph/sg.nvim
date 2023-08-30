use std::{fs::File, io::Write};

use {anyhow::Result, sg::nvim, tokio::io::BufReader};

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
                let mut f = File::create("/tmp/test.txt").unwrap();
                match message.respond().await {
                    Ok(response) => jsonrpc::write_msg(&mut stdout, response).await?,
                    Err(err) => {
                        write!(f, "failure: {:?}", err).unwrap();
                        eprintln!("Failed to respond: {err:?}");
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
