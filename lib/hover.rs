use {
    crate::{entry, get_graphql},
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
    let remote_file = entry::Entry::new(&uri).await?;
    let remote_file = match remote_file {
        entry::Entry::File(file) => file,
        _ => return Err(anyhow::anyhow!("Can only get references of a file")),
    };

    let response_body = get_graphql::<HoverQuery>(hover_query::Variables {
        repository: remote_file.remote.0,
        revision: remote_file.oid.0,
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
