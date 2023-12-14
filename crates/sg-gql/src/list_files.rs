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
        query_path = "gql/list_files.gql",
        response_derives = "Debug"
    )]
    pub struct ListFilesQuery;
}

pub use private::{list_files_query::Variables, ListFilesQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<Vec<PathInfo>> {
    let remote = variables.name.clone();
    let response = crate::get_graphql::<Query>(client, headers, endpoint, variables).await?;

    let commit = response
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?;

    let oid = commit.abbreviated_oid;
    Ok(commit
        .tree
        .context("expected tree")?
        .entries
        .into_iter()
        .map(|e| PathInfo {
            remote: remote.to_string(),
            oid: oid.clone(),
            path: e.path,
            is_directory: e.is_directory,
        })
        .collect())
}
