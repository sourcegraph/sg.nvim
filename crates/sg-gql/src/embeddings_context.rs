use {anyhow::Result, graphql_client::GraphQLQuery, sg_types::Embedding};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/embeddings_context.gql",
        response_derives = "Debug"
    )]
    pub struct EmbeddingsContextQuery;
}

pub use private::{embeddings_context_query::Variables, EmbeddingsContextQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<Vec<Embedding>> {
    let response = crate::get_graphql::<Query>(client, headers, endpoint, variables).await?;

    let mut embeddings = vec![];
    for result in response.embeddings_search.code_results {
        embeddings.push(Embedding::Code {
            repo: result.repo_name,
            file: result.file_name,
            start: result.start_line as usize,
            finish: result.end_line as usize,
            content: result.content,
        })
    }

    for result in response.embeddings_search.text_results {
        embeddings.push(Embedding::Text {
            repo: result.repo_name,
            file: result.file_name,
            start: result.start_line as usize,
            finish: result.end_line as usize,
            content: result.content,
        })
    }

    Ok(embeddings)
}
