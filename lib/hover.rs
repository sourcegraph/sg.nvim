use {
    crate::{get_commit_hash, get_graphql, uri_from_link},
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
    log::info,
};

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/hover_query.graphql",
    response_derives = "Debug"
)]
pub struct HoverQuery;

// #[derive(GraphQLQuery)]
// #[graphql(
//     schema_path = "gql/schema.graphql",
//     query_path = "gql/search_hover_query.graphql",
//     response_derives = "Debug"
// )]
// pub struct SearchHoverQuery;

pub async fn get_hover(uri: String, line: i64, character: i64) -> Result<String> {
    let uri = crate::normalize_url(&uri);
    let remote_file = uri_from_link(&uri, get_commit_hash).await?;
    info!("Remote File: {:?}", remote_file);

    let response_body = get_graphql::<HoverQuery>(hover_query::Variables {
        repository: remote_file.remote,
        revision: remote_file.commit,
        path: remote_file.path,
        line,
        character,
    })
    .await?;

    info!("Got a responsew!");
    Ok(response_body
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
