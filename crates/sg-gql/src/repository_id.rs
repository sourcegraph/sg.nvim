use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
};

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
    endpoint: String,
    variables: Variables,
) -> Result<String> {
    let response = crate::get_graphql::<Query>(client, endpoint, variables).await?;

    match response.repository {
        Some(repo) => Ok(repo.id),
        None => Err(anyhow::anyhow!("Could not find repo")),
    }
}
