use {
    anyhow::Result,
    serde::{Deserialize, Serialize},
    sg_types::*,
    std::{collections::HashMap, io, sync::atomic::AtomicUsize},
};

type MessageReader = dyn tokio::io::AsyncBufRead + Unpin + Send;

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum Message {
    Request(Request),
    Response(Response),
    Notification(Notification),
}

impl Message {
    pub fn new_request(request_type: RequestMethods) -> Self {
        Self::Request(Request::new(request_type))
    }

    pub fn initialize(workspace_root_path: String) -> Self {
        Message::Request(Request::new(RequestMethods::Initialize(ClientInfo {
            name: "neovim".to_string(),
            version: "v1".to_string(),
            workspace_root_path,
            // TODO: Connection configuration
            connection_configuration: None,
            // TODO: Capabilities
            capabilities: None,
        })))
    }

    pub async fn read(r: &mut MessageReader) -> io::Result<Option<Message>> {
        Message::_read(r).await
    }

    async fn _read(r: &mut MessageReader) -> io::Result<Option<Message>> {
        let text = match read_msg_text(r).await? {
            None => return Ok(None),
            Some(text) => text,
        };
        let msg = serde_json::from_str(&text)?;
        Ok(Some(msg))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ConnectionConfiguration {
    pub server_endpoint: String,
    pub access_token: String,
    pub custom_headers: HashMap<String, String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum CompletionCapabilities {
    None,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum ChatCapabilities {
    None,
    Streaming,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ClientCapabilities {
    pub completions: Option<CompletionCapabilities>,
    //  When 'streaming', handles 'chat/updateMessageInProgress' streaming notifications.
    pub chat: Option<ChatCapabilities>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ClientInfo {
    pub name: String,
    pub version: String,
    pub workspace_root_path: String,
    pub connection_configuration: Option<ConnectionConfiguration>,
    pub capabilities: Option<ClientCapabilities>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method", content = "params", rename_all = "lowercase")]
pub enum RequestMethods {
    Initialize(ClientInfo),
    Shutdown,

    #[serde(rename = "recipes/list")]
    RecipesList,

    #[serde(rename = "recipes/execute", rename_all = "camelCase")]
    RecipesExecute {
        id: RecipeID,
        human_chat_input: String,
    },
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Request {
    pub id: usize,

    #[serde(flatten)]
    pub params: RequestMethods,
}

static REQUEST_ID: AtomicUsize = AtomicUsize::new(0);

impl Request {
    pub fn new(params: RequestMethods) -> Request {
        let id = REQUEST_ID.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        Self { id, params }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ServerInfo {
    pub name: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum ResponseTypes {
    ServerInfo(ServerInfo),
    Recipes(Vec<RecipeInfo>),
    Null,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Response {
    pub id: usize,
    pub result: ResponseTypes,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "lowercase")]
pub enum ChatSpeaker {
    Human,
    Assistant,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ContextFile {
    file_name: String,
    repo_name: Option<String>,
    revision: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ChatMessage {
    speaker: ChatSpeaker,
    text: Option<String>,
    display_text: Option<String>,
    context_files: Option<Vec<ContextFile>>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method", content = "params")]
pub enum Notification {
    #[serde(rename = "chat/updateMessageInProgress")]
    UpdateChat(Option<ChatMessage>),
}

async fn read_msg_text(inp: &mut MessageReader) -> io::Result<Option<String>> {
    use tokio::io::{AsyncBufReadExt, AsyncReadExt};

    fn invalid_data(error: impl Into<Box<dyn std::error::Error + Send + Sync>>) -> io::Error {
        io::Error::new(io::ErrorKind::InvalidData, error)
    }
    macro_rules! invalid_data {
        ($($tt:tt)*) => (invalid_data(format!($($tt)*)))
    }

    let mut size = None;
    let mut buf = String::new();
    loop {
        buf.clear();
        if inp.read_line(&mut buf).await? == 0 {
            return Ok(None);
        }
        if !buf.ends_with("\r\n") {
            return Err(invalid_data!("malformed header: {:?}", buf));
        }
        let buf = &buf[..buf.len() - 2];
        if buf.is_empty() {
            break;
        }
        let mut parts = buf.splitn(2, ": ");
        let header_name = parts.next().unwrap();
        let header_value = parts
            .next()
            .ok_or_else(|| invalid_data!("malformed header: {:?}", buf))?;
        if header_name == "Content-Length" {
            size = Some(header_value.parse::<usize>().map_err(invalid_data)?);
        }
    }
    let size: usize = size.ok_or_else(|| invalid_data!("no Content-Length"))?;
    let mut buf = buf.into_bytes();
    buf.resize(size, 0);
    inp.read_exact(&mut buf).await?;
    let buf = String::from_utf8(buf).map_err(invalid_data)?;

    Ok(Some(buf))
}

pub async fn write_msg(mut out: impl tokio::io::AsyncWrite + Unpin, req: Message) -> Result<()> {
    use tokio::io::AsyncWriteExt;

    let msg = serde_json::to_string(&req)?;

    let header = format!("Content-Length: {}\r\n\r\n", msg.len());
    out.write_all(header.as_bytes()).await?;
    out.write_all(msg.as_bytes()).await?;
    out.flush().await?;

    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_can_read_result() {
        let contents = r#"{"jsonrpc":"2.0","id":1,"result":{"name":"cody-agent"}}"#;
        let msg: Message = serde_json::from_str(contents).expect("to read result");
        assert!(matches!(msg, Message::Response(_)))
    }

    #[test]
    fn test_can_read_update_message() {
        let contents = r#"{"jsonrpc":"2.0","method":"chat/updateMessageInProgress","params":{"speaker":"assistant","contextFiles":[]}}"#;
        let msg: Message = serde_json::from_str(contents).expect("to read update message");
        assert!(matches!(
            msg,
            Message::Notification(Notification::UpdateChat(_))
        ))
    }

    #[test]
    fn test_can_read_null_result() {
        let contents = r#"{"jsonrpc":"2.0","id":1,"result":null}"#;
        let msg: Message = serde_json::from_str(contents).expect("to read null result");
        assert!(matches!(msg, Message::Response(_)))
    }
}
