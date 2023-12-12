use {
    anyhow::{Context, Result},
    reqwest::Url,
};

fn main() -> Result<()> {
    let server = tiny_http::Server::http("127.0.0.1:50296").unwrap();
    let addr = dbg!(server.server_addr());

    let ip = match addr {
        tiny_http::ListenAddr::IP(ip) => ip,
        _ => todo!(),
    };
    let port = ip.port();

    // TODO: Get a neovim one (but this is fine for now)
    let redirect = format!("/user/settings/tokens/new/callback?requestFrom=JETBRAINS-{port}");

    println!("Listening on port {}", port);
    let request = server.recv();
    let request = dbg!(request?);

    let url = format!("http://127.0.0.1:{}{}", port, request.url());
    let url = Url::parse(&url)?;
    url.query_pairs()
        .for_each(|(k, v)| println!("{}: {}", k, v));

    let response = tiny_http::Response::from_string(
        "Credentials have been saved to Neovim. Restart Neovim now.",
    );
    request.respond(response).context("replying")?;

    Ok(())
}
