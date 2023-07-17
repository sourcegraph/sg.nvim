use {
    anyhow::Result,
    serde::{de::DeserializeOwned, Serialize},
    std::io,
};

type MessageReader = dyn tokio::io::AsyncBufRead + Unpin + Send;

pub async fn write_msg(
    mut out: impl tokio::io::AsyncWrite + Unpin,
    req: impl Serialize,
) -> Result<()> {
    use tokio::io::AsyncWriteExt;

    let msg = serde_json::to_string(&req)?;

    let header = format!("Content-Length: {}\r\n\r\n", msg.len());
    out.write_all(header.as_bytes()).await?;
    out.write_all(msg.as_bytes()).await?;
    out.flush().await?;

    Ok(())
}

pub async fn read_msg<T>(r: &mut MessageReader) -> Result<Option<T>>
where
    T: DeserializeOwned,
{
    let text = match read_msg_text(r).await? {
        None => return Ok(None),
        Some(text) => text,
    };
    let msg = serde_json::from_str(&text)?;
    Ok(Some(msg))
}

pub async fn read_msg_text(inp: &mut MessageReader) -> Result<Option<String>> {
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
            return Err(anyhow::anyhow!("malformed header: {:?}", buf));
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
