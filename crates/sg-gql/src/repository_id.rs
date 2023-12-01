use {anyhow::Result, graphql_client::GraphQLQuery};

pub(super) mod private {
    use super::*;
    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/repository_id.gql",
        response_derives = "Debug"
    )]
    pub struct RepositoryIDQuery;
}

pub use private::{repository_id_query::Variables, RepositoryIDQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<String> {
    let response = crate::get_graphql::<Query>(client, headers, endpoint, variables).await?;

    match response.repository {
        Some(repo) => Ok(repo.id),
        None => Err(anyhow::anyhow!("Could not find repo")),
    }
}
