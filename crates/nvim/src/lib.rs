use {
    serde::{Deserialize, Serialize},
    sg_types::{Embedding, RecipeInfo},
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
        id: i32,
        repo: String,
        query: String,
        code: i64,
        text: i64,
    },

    ListRecipes {
        id: i32,
    },
}

// impl Request {
//     pub async fn respond(
//         self,
//         tx_cody: &Sender<Message>,
//         rx_cody: &mut Receiver<Message>,
//     ) -> Result<Response> {
//         match self {
//             Request::Echo { id, message, delay } => {
//                 if let Some(delay) = delay {
//                     thread::sleep(Duration::from_secs(delay as u64));
//                 }
//
//                 Ok(Response::Echo { id, message })
//             }
//             Request::Complete { id, message } => {
//                 eprintln!("[sg-cody] complete: {id}");
//                 let completion = match get_cody_completions(message, None).await {
//                     Ok(completion) => completion,
//                     Err(err) => {
//                         return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
//                     }
//                 };
//
//                 Ok(Response::Complete { id, completion })
//             }
//             Request::Repository { id, name } => {
//                 eprintln!("[sg-cody] repo: {id} {name}");
//                 let repository = match get_repository_id(name).await {
//                     Ok(repo) => repo,
//                     Err(err) => {
//                         return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
//                     }
//                 };
//
//                 Ok(Response::Repository { id, repository })
//             }
//             Request::Embedding {
//                 id,
//                 repo,
//                 query,
//                 code,
//                 text,
//             } => {
//                 eprintln!("[sg-cody] repo: {id} {repo}");
//                 let embeddings = match get_embeddings_context(repo, query, code, text).await {
//                     Ok(embeddings) => embeddings,
//                     Err(err) => {
//                         return Err(anyhow::anyhow!("failed to get completions: {err:?}"));
//                     }
//                 };
//
//                 Ok(Response::Embedding { id, embeddings })
//             }
//             Request::ListRecipes { id } => {
//                 eprintln!("[sg-cody] list recipes {id}");
//                 tx_cody.send(Message::new_request(RequestMethods::RecipesList))?;
//
//                 // TODO: I don't like that I can't be 100% sure that we're going to
//                 // get this response next... I'm a little worried about race conditions...
//                 // but oh well :)
//                 loop {
//                     let msg = rx_cody.recv().await;
//                     match msg {
//                         Ok(Message::Response(cody::Response {
//                             id,
//                             result: ResponseTypes::Recipes(recipes),
//                         })) => {
//                             return Ok(Response::ListRecipes {
//                                 id: id as i32,
//                                 recipes,
//                             })
//                         }
//                         _ => continue,
//                     }
//                 }
//             }
//         }
//     }
// }

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "method")]
pub struct Response {
    pub id: usize,

    #[serde(flatten)]
    pub data: ResponseData,
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
}
