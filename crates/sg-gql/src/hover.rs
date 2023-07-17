use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/hover.gql",
        response_derives = "Debug"
    )]
    pub struct HoverQuery;
}

pub use private::{hover_query::Variables, HoverQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    endpoint: String,
    variables: Variables,
) -> Result<String> {
    let response = crate::get_graphql::<Query>(client, endpoint, variables).await?;

    Ok(response
        .repository
        .context("No matching repository")?
        .commit
        .context("No matching commit")?
        .blob
        .context("No matching blob")?
        .lsif
        .context("No corresponding code intelligence")?
        .hover
        .context("no hover")?
        .markdown
        .text)
}
