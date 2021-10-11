use std::error::Error;

use log::debug;
use log::info;
use log::LevelFilter;
use log4rs::append::file::FileAppender;
use log4rs::config::Appender;
use log4rs::config::Config;
use log4rs::config::Root;
use log4rs::encode::pattern::PatternEncoder;
use lsp_server::Connection;
use lsp_server::Message;
use lsp_server::Request;
use lsp_server::RequestId;
use lsp_server::Response;
use lsp_types::request::GotoDefinition;
use lsp_types::request::References;
use lsp_types::GotoDefinitionResponse;
use lsp_types::InitializeParams;
use lsp_types::ServerCapabilities;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error + Sync + Send>> {
    let file_path = "/home/tjdevries/.cache/nvim/sg-lsp.log";

    // Logging to log file.
    let logfile = FileAppender::builder()
        // Pattern: https://docs.rs/log4rs/*/log4rs/encode/pattern/index.html
        .encoder(Box::new(PatternEncoder::new("{l} - {m}\n")))
        .build(file_path)
        .unwrap();

    let config = Config::builder()
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(Root::builder().appender("logfile").build(LevelFilter::Trace))
        .unwrap();

    // Use this to change log levels at runtime.
    // This means you can change the default log level to trace
    // if you are trying to debug an issue and need more logs on then turn it off
    // once you are done.
    let _handle = log4rs::init_config(config)?;

    // Note that  we must have our logging only write out to stderr.
    info!("starting sg-lsp");

    // Create the transport. Includes the stdio (stdin and stdout) versions but this could
    // also be implemented to use sockets or HTTP.
    let (connection, io_threads) = Connection::stdio();

    // Run the server and wait for the two threads to end (typically by trigger LSP Exit event).
    let mut capabilities = ServerCapabilities::default();
    capabilities.definition_provider = Some(lsp_types::OneOf::Left(true));
    capabilities.references_provider = Some(lsp_types::OneOf::Left(true));

    let server_capabilities = serde_json::to_value(&capabilities).unwrap();
    let initialization_params = connection.initialize(server_capabilities)?;

    main_loop(connection, initialization_params).await?;
    io_threads.join()?;

    // Shut down gracefully.
    info!("shutting down server");
    Ok(())
}

async fn main_loop(connection: Connection, params: serde_json::Value) -> Result<(), Box<dyn Error + Sync + Send>> {
    let _params: InitializeParams = serde_json::from_value(params).unwrap();

    for msg in &connection.receiver {
        info!("=========================\ngot msg: {:?}", msg);

        match msg {
            Message::Request(req) => {
                if connection.handle_shutdown(&req)? {
                    return Ok(());
                }

                debug!("got request: {:?}", req);
                let req = match cast::<GotoDefinition>(req) {
                    Ok((id, params)) => {
                        let params = params.text_document_position_params;
                        let uri = params.text_document.uri;
                        let definitions = sg::definition::get_definitions(
                            uri.to_string(),
                            params.position.line as i64,
                            params.position.character as i64,
                        )
                        .await?;

                        let result = Some(GotoDefinitionResponse::Array(definitions));
                        let result = serde_json::to_value(&result).unwrap();
                        let resp = Response {
                            id,
                            result: Some(result),
                            error: None,
                        };
                        connection.sender.send(Message::Response(resp))?;
                        continue;
                    }
                    Err(req) => req,
                };

                let req = match cast::<References>(req) {
                    Ok((id, params)) => {
                        let params = params.text_document_position;
                        let uri = params.text_document.uri;
                        let definitions = sg::references::get_references(
                            uri.to_string(),
                            params.position.line as i64,
                            params.position.character as i64,
                        )
                        .await?;

                        let result = Some(definitions);
                        let result = serde_json::to_value(&result).unwrap();
                        let resp = Response {
                            id,
                            result: Some(result),
                            error: None,
                        };
                        connection.sender.send(Message::Response(resp))?;
                        continue;
                    }
                    Err(req) => req,
                };
                // ...
            }
            Message::Response(resp) => {
                info!("got response: {:?}", resp);
            }
            Message::Notification(not) => {
                info!("got notification: {:?}", not);
            }
        }
    }
    Ok(())
}

fn cast<R>(req: Request) -> Result<(RequestId, R::Params), Request>
where
    R: lsp_types::request::Request,
    R::Params: serde::de::DeserializeOwned,
{
    req.extract(R::METHOD)
}
