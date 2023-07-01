use {
    anyhow::Result,
    serde::{Deserialize, Serialize},
    sg_types::{Embedding, RecipeInfo},
    std::{thread, time::Duration},
    tokio::sync::broadcast::{Receiver, Sender},
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
#[serde(tag = "method")]
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

    ListRecipes {},

    StreamingComplete {
        message: String,
    },
}

#[allow(unused_variables)]
impl Request {
    pub async fn respond(
        self,
        tx_cody: &Sender<cody::Message>,
        rx_cody: &mut Receiver<cody::Message>,
    ) -> Result<Response> {
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
                // let repository = match get_repository_id(name).await {
                //     Ok(repo) => repo,
                //     Err(err) => {
                //         return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                //     }
                // };
                //
                // Ok(Response::Repository { id, repository })
                todo!()
            }
            RequestData::Embedding {
                repo,
                query,
                code,
                text,
            } => {
                eprintln!("[sg-cody] repo: {id} {repo}");
                // let embeddings = match get_embeddings_context(repo, query, code, text).await {
                //     Ok(embeddings) => embeddings,
                //     Err(err) => {
                //         return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
                //     }
                // };
                //
                // Ok(Response::Embedding { id, embeddings })
                todo!()
            }
            RequestData::ListRecipes {} => {
                eprintln!("[sg-cody] list recipes {id}");
                tx_cody.send(cody::Message::new_request(
                    cody::RequestMethods::RecipesList,
                ))?;

                // TODO: I don't like that I can't be 100% sure that we're going to
                // get this response next... I'm a little worried about race conditions...
                // but oh well :)
                loop {
                    let msg = rx_cody.recv().await;
                    match msg {
                        Ok(cody::Message::Response(cody::Response {
                            id,
                            result: cody::ResponseTypes::Recipes(recipes),
                        })) => return Ok(Response::new(id, ResponseData::ListRecipes { recipes })),
                        _ => continue,
                    }
                }
            }
            RequestData::StreamingComplete { message } => {
                eprintln!("[sg-cody] streaming complete {message:?}");
                tx_cody.send(cody::Message::new_request(
                    cody::RequestMethods::RecipesExecute {
                        id: "chat-question".to_string(),
                        human_chat_input: message,
                    },
                ))?;

                Ok(Response::new(
                    id,
                    ResponseData::Echo {
                        message: "started a chat".to_string(),
                    },
                ))
            }
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method")]
pub struct Response {
    pub id: usize,

    #[serde(flatten)]
    pub data: ResponseData,
}

impl Response {
    pub fn new(id: usize, data: ResponseData) -> Self {
        Self { id, data }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method")]
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
