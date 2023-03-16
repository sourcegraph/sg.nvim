use {
    log::{info, LevelFilter},
    log4rs::{
        append::file::FileAppender,
        config::{Appender, Config, Root},
        encode::pattern::PatternEncoder,
    },
    lsp_server::{Connection, ExtractError, Message, Request, RequestId, Response},
    lsp_types::{
        request::{GotoDefinition, HoverRequest, References},
        GotoDefinitionParams, GotoDefinitionResponse, Hover, HoverParams, InitializeParams,
        ReferenceParams, ServerCapabilities,
    },
    serde::{Deserialize, Serialize},
    std::{error::Error, path::Path},
};

type BoxErr = Box<dyn Error + Sync + Send>;
type Res<T> = Result<T, BoxErr>;

mod sg_read {
    use super::*;

    #[derive(Debug)]
    pub enum Request {}

    #[derive(Debug, Eq, PartialEq, Clone, Deserialize, Serialize)]
    #[serde(rename_all = "camelCase")]
    pub struct Params {
        pub path: String,
    }

    #[derive(Debug, PartialEq, Serialize, Deserialize, Clone)]
    pub struct Response {
        pub normalized: String,
    }

    impl lsp_types::request::Request for Request {
        type Params = Params;
        type Result = Option<Response>;
        const METHOD: &'static str = "$sourcegraph/get_remote_file";
    }
}

#[tokio::main]
async fn main() -> Res<()> {
    let file_path = "/home/tjdevries/.cache/nvim/sg-lsp.log";

    // TODO: Make logging work for everyone and configurable,
    // but for now I don't want to write to other people's systems
    if Path::new(file_path).exists() {
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
    }

    // Note that  we must have our logging only write out to stderr.
    info!("starting generic LSP server");

    // Create the transport. Includes the stdio (stdin and stdout) versions but this could
    // also be implemented to use sockets or HTTP.
    let (connection, io_threads) = Connection::stdio();

    // Run the server and wait for the two threads to end (typically by trigger LSP Exit event).
    let capabilities = ServerCapabilities {
        definition_provider: Some(lsp_types::OneOf::Left(true)),
        references_provider: Some(lsp_types::OneOf::Left(true)),
        hover_provider: Some(lsp_types::HoverProviderCapability::Simple(true)),
        ..Default::default()
    };

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

async fn handle_definition(
    connection: &Connection,
    id: RequestId,
    params: GotoDefinitionParams,
) -> Res<()> {
    let params = params.text_document_position_params;
    let uri = params.text_document.uri;
    let definitions = sg::definition::get_definitions(
        uri.to_string(),
        params.position.line as i64,
        params.position.character as i64,
    )
    .await?;

    let result = Some(GotoDefinitionResponse::Array(definitions));
    let result = serde_json::to_value(result).unwrap();
    let resp = Response {
        id,
        result: Some(result),
        error: None,
    };
    connection.sender.send(Message::Response(resp))?;
    Ok(())
}

async fn handle_hover(connection: &Connection, id: RequestId, params: HoverParams) -> Res<()> {
    let params = params.text_document_position_params;
    let hover = sg::hover::get_hover(
        params.text_document.uri.to_string(),
        params.position.line as i64,
        params.position.character as i64,
    )
    .await?;

    let result = Some(Hover {
        contents: lsp_types::HoverContents::Markup(lsp_types::MarkupContent {
            kind: lsp_types::MarkupKind::Markdown,
            value: hover,
        }),
        range: None,
    });
    let result = serde_json::to_value(&result).unwrap();
    let resp = Response {
        id,
        result: Some(result),
        error: None,
    };
    connection.sender.send(Message::Response(resp))?;
    Ok(())
}

async fn handle_references(
    connection: &Connection,
    id: RequestId,
    params: ReferenceParams,
) -> Res<()> {
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
    Ok(())
}

// pub trait Request {
//     type Params: DeserializeOwned + Serialize;
//     type Result: DeserializeOwned + Serialize;
//     const METHOD: &'static str;
// }

async fn handle_sourcegraph_read(
    connection: &Connection,
    id: RequestId,
    params: sg_read::Params,
) -> Res<()> {
    info!("Reading sg:// -> {} ", params.path);
    let resp = Some(sg_read::Response {
        normalized: sg::normalize_url(&params.path),
    });
    let resp = serde_json::to_value(&resp).unwrap();
    let resp = Response {
        id,
        result: Some(resp),
        error: None,
    };
    connection.sender.send(Message::Response(resp))?;
    Ok(())
}

async fn main_loop(connection: Connection, params: serde_json::Value) -> Res<()> {
    let _params: InitializeParams = serde_json::from_value(params).unwrap();
    info!("Starting main loop...");

    for msg in &connection.receiver {
        info!("got msg: {:?}", msg);
        match msg {
            Message::Request(req) => {
                if connection.handle_shutdown(&req)? {
                    return Ok(());
                }

                handle_request(&connection, req).await?;
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

fn send_error(connection: &Connection, id: RequestId, err: BoxErr) {
    connection
        .sender
        .send(Message::Response(Response {
            id,
            result: None,
            error: Some(lsp_server::ResponseError {
                code: -32700,
                message: format!("{err:?}"),
                data: None,
            }),
        }))
        .expect("Failed to send response");
}

async fn handle_request(connection: &Connection, req: Request) -> Res<()> {
    // Make sure that we don't crash the server just because some requests aren't handled
    // correctly.
    //
    // Instead we respond with an error and continue working
    macro_rules! handle_one {
        ($connection: ident, $req: ident, $base: ty, $handler: ident) => {{
            let id = $req.id.clone();
            let req = $req.clone();
            match cast::<$base>(req) {
                Ok((id, params)) => match $handler($connection, id.clone(), params).await {
                    Ok(_) => return Ok(()),
                    Err(err) => {
                        send_error($connection, id, err);
                        return Ok(());
                    }
                },
                Err(ExtractError::MethodMismatch(req)) => req,
                Err(err) => {
                    send_error($connection, id, err.into());
                    return Ok(());
                }
            }
        }};
    }

    handle_one!(connection, req, GotoDefinition, handle_definition);
    handle_one!(connection, req, References, handle_references);
    handle_one!(connection, req, HoverRequest, handle_hover);

    // Useful requests for other clients, that don't have a way to easily use FFI
    //      You will have to implement handlers for these in your client
    //      (same as you would via FFI, except you incur the cost of mixing LSP w/ non-LSP stuff)
    handle_one!(connection, req, sg_read::Request, handle_sourcegraph_read);

    Ok(())
}

fn cast<R>(req: Request) -> Result<(RequestId, R::Params), ExtractError<Request>>
where
    R: lsp_types::request::Request,
    R::Params: serde::de::DeserializeOwned,
{
    req.extract(R::METHOD)
}
