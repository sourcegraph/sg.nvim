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

pub use private::CompletionQuery as Query;

#[derive(Debug)]
pub struct Variables {
    pub messages: Vec<CodyMessage>,
    pub temperature: Option<f64>,
}

impl From<Variables> for private::completion_query::Variables {
    fn from(val: Variables) -> Self {
        use private::completion_query::{Message, SpeakerType};
        let Variables {
            messages,
            temperature,
        } = val;

        let messages = messages
            .into_iter()
            .map(|msg| Message {
                speaker: match msg.speaker {
                    sg_types::CodySpeaker::Human => SpeakerType::HUMAN,
                    sg_types::CodySpeaker::Assistant => SpeakerType::ASSISTANT,
                },
                text: msg.text,
            })
            .collect();

        Self {
            messages,
            temperature: temperature.unwrap_or(0.5),
            max_tokens_to_sample: 1000,
            top_k: -1,
            top_p: -1,
        }
    }
}

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: private::completion_query::Variables,
) -> Result<String> {
    let response = crate::get_graphql::<Query>(client, headers, endpoint, variables).await?;
    Ok(response.completions)
}
