use {crate::get_graphql, anyhow::Result, graphql_client::GraphQLQuery};

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/completions_query.graphql",
    response_derives = "Debug"
)]
pub struct CompletionQuery;

pub use completion_query::{Message, SpeakerType};

pub struct Response {
    pub messages: Vec<Message>,
    pub completions: String,
}

pub async fn get_completions(text: String, temp: Option<f64>) -> Result<String> {
    let messages = vec![
        Message {
            speaker: SpeakerType::ASSISTANT,
            text: "I am Cody, an AI-powered coding assistant developed by Sourcegraph. I operate inside a Language Server Protocol implementation. My task is to help programmers with programming tasks in the %s programming language.
I have access to your currently open files in the editor.
I will generate suggestions as concisely and clearly as possible.
I only suggest something if I am certain about my answer.".to_string(),
        },
        Message {
            speaker: SpeakerType::HUMAN,
            text,
        },
        Message {
            speaker: SpeakerType::ASSISTANT,
            text: "".to_string(),
        },
    ];

    let response_body = get_graphql::<CompletionQuery>(completion_query::Variables {
        messages,
        temperature: temp.unwrap_or(0.2),
        max_tokens_to_sample: 1000,
        top_k: -1,
        top_p: -1,
    })
    .await?;

    let completions = response_body.completions;
    Ok(completions)
}
