use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
    sg_types::*,
};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/commit_query.gql",
        response_derives = "Debug"
    )]
    pub struct CommitQuery;
}

pub use private::{commit_query::Variables, CommitQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    endpoint: String,
    variables: Variables,
) -> Result<String> {
    let response = crate::get_graphql::<Query>(client, endpoint, variables).await?;

    Ok(response
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?
        .oid)
}
