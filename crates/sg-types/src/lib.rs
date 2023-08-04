use {
    anyhow::Result,
    serde::{Deserialize, Serialize},
    std::str::FromStr,
};

pub type ID = String;
pub type GitObjectID = String;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum Embedding {
    Code {
        repo: String,
        file: String,
        start: usize,
        finish: usize,
        content: String,
    },
    Text {
        repo: String,
        file: String,
        start: usize,
        finish: usize,
        content: String,
    },
}

#[derive(Debug)]
pub enum CodySpeaker {
    Human,
    Assistant,
}

#[derive(Debug)]
pub struct CodyMessage {
    pub speaker: CodySpeaker,
    pub text: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct PathInfo {
    pub remote: String,
    pub oid: String,
    pub path: String,
    pub is_directory: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SourcegraphVersion {
    pub product: String,
    pub build: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Remote(pub String);

impl Remote {
    pub fn shortened(&self) -> String {
        if self.0 == "github.com" {
            "gh".to_string()
        } else {
            self.0.to_owned()
        }
    }
}

impl From<String> for Remote {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl FromStr for Remote {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self(s.to_string()))
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct OID(pub String);

impl OID {
    pub fn shortened(&self) -> String {
        if self.0.len() < 5 {
            self.0.to_string()
        } else {
            self.0[..5].to_string()
        }
    }
}

impl From<String> for OID {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl FromStr for OID {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self(s.to_string()))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub repo: String,
    pub file: String,
    pub preview: String,
    pub line: usize,
}

pub type RecipeID = String;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RecipeInfo {
    pub id: RecipeID,
    pub title: String,
}
