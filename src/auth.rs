use {
    anyhow::{Context, Result},
    once_cell::sync::Lazy,
    serde::{Deserialize, Serialize},
    std::sync::Mutex,
};

#[derive(Serialize, Deserialize)]
pub struct CodyCredentials {
    pub endpoint: Option<String>,
    pub token: Option<String>,
}

static ACCESS_TOKEN: Lazy<Mutex<Option<String>>> = Lazy::new(|| {
    fn get_token() -> Option<String> {
        if let Ok(token) = std::env::var("SRC_ACCESS_TOKEN") {
            if !token.is_empty() {
                return Some(token);
            }
        }

        if let Some(CodyCredentials {
            token: Some(token), ..
        }) = get_credentials()
        {
            return Some(token);
        };

        None
    }

    Mutex::new(get_token())
});

static ENDPOINT: Lazy<Mutex<Option<String>>> = Lazy::new(|| {
    fn get_token() -> Option<String> {
        if let Ok(token) = std::env::var("SRC_ENDPOINT") {
            if !token.is_empty() {
                return Some(token);
            }
        }

        if let Some(CodyCredentials {
            endpoint: Some(token),
            ..
        }) = get_credentials()
        {
            return Some(token);
        };

        None
    }

    Mutex::new(get_token())
});

pub fn get_access_token() -> Option<String> {
    ACCESS_TOKEN.lock().expect("to unlock access token").clone()
}

pub fn get_endpoint() -> String {
    ENDPOINT
        .lock()
        .expect("to unlock endpoint")
        .clone()
        .unwrap_or_else(|| "https://sourcegraph.com/".to_string())
        .trim_end_matches('/')
        .to_string()
}

fn get_entry() -> Result<keyring::Entry> {
    let username = whoami::username();
    keyring::Entry::new("cody-access-token", &username).context("getting keyring entry")
}

fn get_credentials() -> Option<CodyCredentials> {
    let entry = get_entry().ok()?;
    let token = entry.get_password().ok()?;
    serde_json::from_str(&token).ok()
}

pub fn set_credentials(credentials: CodyCredentials) -> Result<()> {
    if let Some(token) = &credentials.token {
        std::env::set_var("SRC_ACCESS_TOKEN", token);
    }

    if let Some(endpoint) = &credentials.endpoint {
        std::env::set_var("SRC_ENDPOINT", endpoint);
    }

    let entry = get_entry()?;
    entry
        .set_password(&serde_json::to_string(&credentials)?)
        .context("set_credentials")
}
