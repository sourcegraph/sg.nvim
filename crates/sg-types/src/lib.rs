use serde::{Deserialize, Serialize};

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
