use {
    log::{info, LevelFilter},
    log4rs::{
        append::file::FileAppender,
        config::{Appender, Config, Root},
        encode::pattern::PatternEncoder,
    },
    lsp_server::{Connection, ExtractError, Message, Request, RequestId, Response},
    lsp_types::{
        request::{GotoDefinition, References},
        GotoDefinitionResponse, InitializeParams, ServerCapabilities,
    },
    serde::{Deserialize, Serialize},
    std::error::Error,
};

#[derive(Debug)]
pub enum SourcegraphRead {}

#[derive(Debug, Eq, PartialEq, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SourcegraphReadParams {
    pub path: String,
}

#[derive(Debug, PartialEq, Serialize, Deserialize, Clone)]
pub struct SourcegraphReadResponse {
    pub normalized: String,
}

impl lsp_types::request::Request for SourcegraphRead {
    type Params = SourcegraphReadParams;
    type Result = Option<SourcegraphReadResponse>;
    const METHOD: &'static str = "$sourcegraph/get_remote_file";
}

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
    capabilities.references_provider = Some(lsp_types::OneOf::Left(true));

    let server_capabilities = serde_json::to_value(&capabilities).unwrap();
    let initialization_params = match connection.initialize(server_capabilities) {
        Ok(params) => params,
        Err(err) => {
            // Yes, leave the log in since the panic message is often lost when running
            // the lsp
            info!("Failed with err: {:?}", err);

            panic!("Failed with err: {:?}", err)
        }
    };

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
    info!("Starting main loop...");

    for msg in &connection.receiver {
        info!("got msg: {:?}", msg);
        match msg {
            Message::Request(req) => {
                if connection.handle_shutdown(&req)? {
                    return Ok(());
                }

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
                    Err(ExtractError::MethodMismatch(req)) => req,
                    Err(req) => panic!("error: {:?}", req),
                };

                let req = match cast::<References>(req) {
                    Ok((id, params)) => {
                        let params = params.text_document_position;
                        let uri = params.text_document.uri;
                        let references = sg::references::get_references(
                            uri.to_string(),
                            params.position.line as i64,
                            params.position.character as i64,
                        )
                        .await?;

                        let result = Some(references);
                        let result = serde_json::to_value(&result).unwrap();
                        let resp = Response {
                            id,
                            result: Some(result),
                            error: None,
                        };
                        connection.sender.send(Message::Response(resp))?;
                        continue;
                    }
                    Err(ExtractError::MethodMismatch(req)) => req,
                    Err(req) => panic!("error: {:?}", req),
                };

                let req = match cast::<SourcegraphRead>(req) {
                    Ok((id, params)) => {
                        info!("Reading sg:// -> {} ", params.path);
                        let resp = Some(SourcegraphReadResponse {
                            normalized: sg::normalize_url(&params.path),
                        });
                        let resp = serde_json::to_value(&resp).unwrap();
                        let resp = Response {
                            id,
                            result: Some(resp),
                            error: None,
                        };
                        connection.sender.send(Message::Response(resp))?;
                        continue;
                    }
                    Err(ExtractError::MethodMismatch(req)) => req,
                    Err(req) => panic!("Failed to parse sg msg with: {:?}", req),
                };

                _ = req

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

    info!("ALL DONE");
    Ok(())
}

fn cast<R>(req: Request) -> Result<(RequestId, R::Params), ExtractError<Request>>
where
    R: lsp_types::request::Request,
    R::Params: serde::de::DeserializeOwned,
{
    req.extract(R::METHOD)
}
