use {anyhow::Result, graphql_client::GraphQLQuery, sg_types::CodyMessage};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/completions_query.gql",
        response_derives = "Debug"
    )]
    pub struct CompletionQuery;
}

use private::completion_query::{Message, SpeakerType};
pub use private::{
    // TODO: Weird to export message here...
    completion_query::Variables,
    CompletionQuery as Query,
};

pub async fn request(
    client: &reqwest::Client,
    endpoint: String,
    variables: Variables,
) -> Result<Vec<CodyMessage>> {
    //     let messages = vec![
    //         Message {
    //             speaker: SpeakerType::ASSISTANT,
    //             text: "I am Cody, an AI-powered coding assistant developed by Sourcegraph. I operate inside a Language Server Protocol implementation. My task is to help programmers with programming tasks in the %s programming language.
    // I have access to your currently open files in the editor.
    // I will generate suggestions as concisely and clearly as possible.
    // I only suggest something if I am certain about my answer.".to_string(),
    //         },
    //         Message {
    //             speaker: SpeakerType::HUMAN,
    //             text,
    //         },
    //         Message {
    //             speaker: SpeakerType::ASSISTANT,
    //             text: "".to_string(),
    //         },
    //     ];
    let _ = crate::get_graphql::<Query>(client, endpoint, variables).await?;

    todo!()
}
