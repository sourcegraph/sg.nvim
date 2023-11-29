use {
    anyhow::{Context, Result},
    secret_service::{EncryptionType, SecretService},
    std::collections::HashMap,
};

const CODY_ACCESS_TOKEN_KEY: &str = "cody-access-token";
const CODY_ACCESS_PROPERTIES: [(&str, &str); 1] = [("cody", "access-token")];

pub async fn set_cody_access_token(value: String) -> Result<()> {
    let ss = SecretService::connect(EncryptionType::Dh).await?;
    let collection = ss
        .get_default_collection()
        .await
        .context("secret-service: default collection")?;

    // create new item
    collection
        .create_item(
            CODY_ACCESS_TOKEN_KEY,                 // label
            HashMap::from(CODY_ACCESS_PROPERTIES), // properties
            value.as_bytes(),                      // secret
            true,                                  // replace item with same attributes
            "text/plain",                          // secret content type
        )
        .await?;

    Ok(())
}

pub async fn get_cody_access_token() -> Result<String> {
    let ss = SecretService::connect(EncryptionType::Dh).await?;
    let collection = ss
        .get_default_collection()
        .await
        .context("secret-service: default collection")?;

    let search_items = collection
        .search_items(CODY_ACCESS_PROPERTIES.into())
        .await?;

    let item = search_items
        .get(0)
        .context("Could not find Cody access token")?;

    // retrieve secret from item
    let secret = item.get_secret().await?;
    let secret = String::from_utf8(secret.to_vec())?;

    Ok(secret)
}
