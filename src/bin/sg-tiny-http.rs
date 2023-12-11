use {anyhow::Result, reqwest::Url};

fn main() -> Result<()> {
    let server = tiny_http::Server::http("127.0.0.1:50296").unwrap();
    let addr = dbg!(server.server_addr());

    let ip = match addr {
        tiny_http::ListenAddr::IP(ip) => ip,
        _ => todo!(),
    };
    let port = ip.port();

    println!("Listening on port {}", port);
    let request = server.recv();
    let request = dbg!(request?);

    let url = format!("http://127.0.0.1:{}{}", port, request.url());
    let url = Url::parse(&url)?;
    url.query_pairs()
        .for_each(|(k, v)| println!("{}: {}", k, v));

    Ok(())
}
