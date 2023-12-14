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
        query_path = "gql/path_info_query.gql",
        response_derives = "Debug"
    )]
    pub struct PathInfoQuery;
}

pub use private::{path_info_query::Variables, PathInfoQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<PathInfo> {
    use private::path_info_query::*;
    let response = crate::get_graphql::<Query>(client, headers, endpoint, variables).await?;

    let repository = response
        .repository
        .context("No matching repository found")?;

    let commit = repository.commit.context("No matching commit found")?;
    let oid = commit.abbreviated_oid;

    let gql_path = commit
        .path
        .ok_or_else(|| anyhow::anyhow!("failed to read path"))?;

    let is_directory = match &gql_path {
        PathInfoQueryRepositoryCommitPath::GitTree(tree) => tree.is_directory,
        PathInfoQueryRepositoryCommitPath::GitBlob(blob) => blob.is_directory,
    };

    let path = match gql_path {
        PathInfoQueryRepositoryCommitPath::GitTree(tree) => tree.path,
        PathInfoQueryRepositoryCommitPath::GitBlob(blob) => blob.path,
    };

    Ok(PathInfo {
        remote: repository.name,
        oid,
        path,
        is_directory,
    })
}
