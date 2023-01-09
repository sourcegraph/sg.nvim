//! A minimal example LSP server that can only respond to the `gotoDefinition` request. To use
//! this example, execute it and then send an `initialize` request.
//!
//! ```no_run
//! Content-Length: 85
//!
//! {"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"capabilities": {}}}
//! ```
//!
//! This will respond with a server response. Then send it a `initialized` notification which will
//! have no response.
//!
//! ```no_run
//! Content-Length: 59
//!
//! {"jsonrpc": "2.0", "method": "initialized", "params": {}}
//! ```
//!
//! Once these two are sent, then we enter the main loop of the server. The only request this
//! example can handle is `gotoDefinition`:
//!
//! ```no_run
//! Content-Length: 159
//!
//! {"jsonrpc": "2.0", "method": "textDocument/definition", "id": 2, "params": {"textDocument": {"uri": "file://temp"}, "position": {"line": 1, "character": 1}}}
//! ```
//!
//! To finish up without errors, send a shutdown request:
//!
//! ```no_run
//! Content-Length: 67
//!
//! {"jsonrpc": "2.0", "method": "shutdown", "id": 3, "params": null}
//! ```
//!
//! The server will exit the main loop and finally we send a `shutdown` notification to stop
//! the server.
//!
//! ```
//! Content-Length: 54
//!
//! {"jsonrpc": "2.0", "method": "exit", "params": null}
//! ```
use {
    log::{info, LevelFilter},
    log4rs::{
        append::file::FileAppender,
        config::{Appender, Config, Root},
        encode::pattern::PatternEncoder,
    },
    lsp_server::{Connection, ExtractError, Message, Request, RequestId, Response},
    lsp_types::{
        request::GotoDefinition, GotoDefinitionResponse, InitializeParams, ServerCapabilities,
    },
    std::error::Error,
};

// #[derive(Debug)]
// pub enum SourcegraphRead {}
//
// #[derive(Debug, Eq, PartialEq, Clone, Deserialize, Serialize)]
// #[serde(rename_all = "camelCase")]
// pub struct SourcegraphReadParams {
//     #[serde(flatten)]
//     pub name: String,
// }
//
// #[derive(Debug, PartialEq, Serialize, Deserialize, Clone)]
// #[serde(untagged)]
// pub enum SourcegraphReadResponse {
//     Something(String),
// }
//
// impl Request for SourcegraphRead {
//     type Params = SourcegraphReadParams;
//     type Result = Option<SourceReadResponse>;
//     const METHOD: &'static str = "$sourcegraph/read";
// }

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
        .build(
            Root::builder()
                .appender("logfile")
                .build(LevelFilter::Trace),
        )
        .unwrap();

    // Use this to change log levels at runtime.
    // This means you can change the default log level to trace
    // if you are trying to debug an issue and need more logs on then turn it off
    // once you are done.
    let _handle = log4rs::init_config(config)?;

    // Note that  we must have our logging only write out to stderr.
    info!("starting generic LSP server");

    // Create the transport. Includes the stdio (stdin and stdout) versions but this could
    // also be implemented to use sockets or HTTP.
    let (connection, io_threads) = Connection::stdio();

    // Run the server and wait for the two threads to end (typically by trigger LSP Exit event).
    let mut capabilities = ServerCapabilities::default();
    capabilities.definition_provider = Some(lsp_types::OneOf::Left(true));

    let server_capabilities = serde_json::to_value(&capabilities).unwrap();
    let initialization_params = connection.initialize(server_capabilities)?;

    main_loop(connection, initialization_params).await?;
    io_threads.join()?;

    // Shut down gracefully.
    info!("shutting down server");
    Ok(())
}

async fn main_loop(
    connection: Connection,
    params: serde_json::Value,
) -> Result<(), Box<dyn Error + Sync + Send>> {
    let _params: InitializeParams = serde_json::from_value(params).unwrap();
    // info!("starting example main loop {:?}", params);
    info!("Starting main loop...");

    for msg in &connection.receiver {
        info!("got msg: {:?}", msg);
        match msg {
            Message::Request(req) => {
                if connection.handle_shutdown(&req)? {
                    return Ok(());
                }

                info!("got request: {:?}", req);
                match cast::<GotoDefinition>(req) {
                    Ok((id, params)) => {
                        info!("===========================");
                        info!("got gotoDefinition request #{}: {:?}", id, params);
                        let params = params.text_document_position_params;
                        let uri = params.text_document.uri;
                        let definitions = sg::definition::get_definitions(
                            uri.to_string(),
                            params.position.line as i64,
                            params.position.character as i64,
                        )
                        .await?;

                        info!("Made it past defintiions");

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

fn cast<R>(req: Request) -> Result<(RequestId, R::Params), ExtractError<Request>>
where
    R: lsp_types::request::Request,
    R::Params: serde::de::DeserializeOwned,
{
    req.extract(R::METHOD)
}
