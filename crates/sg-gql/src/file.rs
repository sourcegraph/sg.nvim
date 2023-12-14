use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/file_query.gql",
        response_derives = "Debug"
    )]
    pub struct FileQuery;
}

pub use private::{file_query::Variables, FileQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<String> {
    let response = crate::get_graphql::<Query>(client, headers, endpoint, variables).await?;

    Ok(response
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?
        .file
        .context("No matching File")?
        .content)
}
