use {
    crate::{get_commit_hash, normalize_url, uri_from_link, CLIENT},
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    log::info,
    lsp_types::{Location, Url},
};

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/references_query.graphql",
    response_derives = "Debug"
)]
pub struct ReferencesQuery;

pub async fn get_references(uri: String, line: i64, character: i64) -> Result<Vec<Location>> {
    let uri = normalize_url(&uri);
    let remote_file = uri_from_link(&uri, get_commit_hash).await?;
    info!("Remote File: {:?}", remote_file);

    let response_body = post_graphql::<ReferencesQuery, _>(
        &CLIENT,
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

    let nodes = response_body
        .data
        .context("data")?
        .repository
        .context("repository")?
        .commit
        .context("commit")?
        .blob
        .context("blob")?
        .lsif
        .context("lsif")?
        .references
        .nodes;

    let mut references: Vec<Location> = Vec::new();
    for node in nodes {
        info!("Checking out node: {:?}", node);
        let range = node
            .range
            .context("Missing range for some IDIOTIC reason??? ME???")?;

        // let sg_url = format!("sg:/{}", node.url);

        let (_, sg_url) = node.url.split_at(1);
        let node_remote = uri_from_link(&sg_url, get_commit_hash).await?;
        info!("Node Remote: {:?}", node_remote);

        references.push(Location {
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

    Ok(references)
}
