use {
    anyhow::Result,
    mlua::ToLua,
    serde::{Deserialize, Serialize},
    std::str::FromStr,
};

pub type ID = String;
pub type GitObjectID = String;

#[derive(Debug, Serialize, Deserialize)]
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

#[derive(Serialize)]
pub struct PathInfo {
    pub remote: String,
    pub oid: String,
    // TODO: Maybe should split out path and name...
    //          Or just always include path, don't just include name
    //          Just do the string manipulation to show the end of the path
    pub path: String,
    pub is_directory: bool,
}

pub struct SourcegraphVersion {
    pub product: String,
    pub build: String,
}

#[derive(Debug, Clone)]
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

impl<'lua> ToLua<'lua> for Remote {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        self.0.to_lua(lua)
    }
}

impl FromStr for Remote {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self(s.to_string()))
    }
}

#[derive(Debug, Clone)]
pub struct OID(pub String);

impl OID {
    pub fn shortened(&self) -> String {
        self.0[..5].to_string()
    }
}

impl From<String> for OID {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl<'lua> ToLua<'lua> for OID {
    fn to_lua(self, lua: &'lua mlua::Lua) -> mlua::Result<mlua::Value<'lua>> {
        self.0.to_lua(lua)
    }
}

impl FromStr for OID {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self(s.to_string()))
    }
}

#[derive(Debug)]
pub struct SearchResult {
    pub repo: String,
    pub file: String,
    pub preview: String,
    pub line: usize,
}
