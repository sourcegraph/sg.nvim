use {
    crate::{get_commit_hash, get_graphql, uri_from_link},
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
    log::info,
    lsp_types::{Location, Url},
};

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/definition_query.graphql",
    response_derives = "Debug"
)]
pub struct DefinitionQuery;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/search_definition_query.graphql",
    response_derives = "Debug"
)]
pub struct SearchDefinitionQuery;

pub async fn get_definitions(uri: String, line: i64, character: i64) -> Result<Vec<Location>> {
    let uri = crate::normalize_url(&uri);
    let remote_file = uri_from_link(&uri, get_commit_hash).await?;
    info!("Remote File: {:?}", remote_file);

    let response_body = get_graphql::<DefinitionQuery>(definition_query::Variables {
        repository: remote_file.remote,
        revision: remote_file.commit,
        path: remote_file.path,
        line,
        character,
    })
    .await?;

    info!("Got a responsew!");
    let nodes = response_body
        .repository
        .context("No matching repository")?
        .commit
        .context("No matching commit")?
        .blob
        .context("No matching blob")?
        .lsif
        .context("No corresponding code intelligence")?
        .definitions
        .nodes;

    let mut definitions: Vec<Location> = Vec::new();
    for node in nodes {
        info!("Checking out node: {:?}", node);
        let range = node
            .range
            .context("Missing range for some IDIOTIC reason??? ME???")?;

        // let sg_url = format!("sg:/{}", node.url);

        let (_, sg_url) = node.url.split_at(1);
        let node_remote = uri_from_link(sg_url, get_commit_hash).await?;
        info!("Node Remote: {:?}", node_remote);

        definitions.push(Location {
            uri: Url::parse(&node_remote.bufname())?,

            // TODO: impl into
            range: lsp_types::Range {
                start: lsp_types::Position {
                    line: range.start.line as u32,
                    character: range.start.character as u32,
                },
                end: lsp_types::Position {
                    line: range.end.line as u32,
                    character: range.end.character as u32,
                },
            },
        })
    }

    Ok(definitions)
}
