use {anyhow::Result, dialoguer::Confirm};

fn main() -> Result<()> {
    dbg!(sg::auth::get_endpoint());
    dbg!(sg::auth::get_access_token());

    let confirmation = Confirm::new()
        .with_prompt("Clear auth?")
        .interact()
        .unwrap();

    if confirmation {
        println!("clearing auth...");

        sg::auth::set_credentials(sg::auth::CodyCredentials {
            endpoint: None,
            token: None,
        })?;
    }
    Ok(())
}
