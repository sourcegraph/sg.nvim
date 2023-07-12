use crate::{get_embeddings_context, get_repository_id};

use {
    anyhow::Result,
    serde::{Deserialize, Serialize},
    sg_types::{Embedding, RecipeInfo},
    std::{thread, time::Duration},
};

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum Message {
    Request(Request),
    Response(Response),
    Notification(Notification),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Request {
    pub id: usize,

    #[serde(flatten)]
    pub data: RequestData,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method", content = "params")]
pub enum RequestData {
    Echo {
        message: String,
        delay: Option<i32>,
    },

    Complete {
        message: String,
    },

    Repository {
        name: String,
    },

    Embedding {
        repo: String,
        query: String,
        code: i64,
        text: i64,
    },
}

#[allow(unused_variables)]
impl Request {
    pub async fn respond(self) -> Result<Response> {
        let Self { id, data } = self;
        match data {
            RequestData::Echo { message, delay } => {
                if let Some(delay) = delay {
                    thread::sleep(Duration::from_secs(delay as u64));
                }

                Ok(Response::new(id, ResponseData::Echo { message }))
            }
            RequestData::Complete { message } => {
                eprintln!("[sg-cody] complete: {id}");
                // let completion = match get_cody_completions(message, None).await {
                //     Ok(completion) => completion,
                //     Err(err) => {
                //         return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                //     }
                // };
                //
                // Ok(Response::Complete { id, completion })
                todo!("have not done sync requests at the moment")
            }
            RequestData::Repository { name } => {
                eprintln!("[sg-cody] repo: {id} {name}");
                let repository = match get_repository_id(name).await {
                    Ok(repo) => repo,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get repository: {err:?}"));
                    }
                };

                Ok(Response::new(id, ResponseData::Repository { repository }))
            }
            RequestData::Embedding {
                repo,
                query,
                code,
                text,
            } => {
                eprintln!("[sg-cody] repo: {id} {repo}");
                let embeddings = match get_embeddings_context(repo, query, code, text).await {
                    Ok(embeddings) => embeddings,
                    Err(err) => {
                        return Err(anyhow::anyhow!("failed to get embeddings: {err:?}"));
                    }
                };

                Ok(Response::new(id, ResponseData::Embedding { embeddings }))
            }
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Response {
    pub id: usize,
    pub result: ResponseData,
}

impl Response {
    pub fn new(id: usize, result: ResponseData) -> Self {
        Self { id, result }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum ResponseData {
    Echo { message: String },
    Complete { completion: String },
    Repository { repository: String },
    Embedding { embeddings: Vec<Embedding> },
    ListRecipes { recipes: Vec<RecipeInfo> },
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Notification {
    UpdateChat { message: String },
    Hack { json: String },
}
