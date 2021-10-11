use anyhow::Context;
use anyhow::Result;
use graphql_client::reqwest::post_graphql;
use graphql_client::GraphQLQuery;
use interprocess::local_socket::LocalSocketStream;
use log::info;
use lsp_types::Location;
use lsp_types::Url;

use crate::RemoteFileMessage;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/references_query.graphql",
    response_derives = "Debug"
)]
pub struct ReferencesQuery;

pub async fn get_references(uri: String, line: i64, character: i64) -> Result<Vec<Location>> {
    let mut conn = LocalSocketStream::connect("/tmp/example.sock")?;
    let remote_file = RemoteFileMessage { path: uri }.get_remote_file(&mut conn)?;

    let client = crate::get_client()?;
    let references_body = post_graphql::<ReferencesQuery, _>(
        &client,
        "https://sourcegraph.com/.api/graphql",
        references_query::Variables {
            repository: remote_file.remote,
            revision: remote_file.commit,
            path: remote_file.path,
            line,
            character,
        },
    )
    .await?;

    info!("references: response");
    let nodes = references_body
        .data
        .context("definition.data")?
        .repository
        .context("No matching repository")?
        .commit
        .context("No matching commit")?
        .blob
        .context("No matching blob")?
        .lsif
        .context("No corresponding code intelligence: references")?
        .references
        .nodes;

    let mut references: Vec<Location> = Vec::new();
    crate::nodes_to_locations!(references, nodes);

    Ok(references)
}
