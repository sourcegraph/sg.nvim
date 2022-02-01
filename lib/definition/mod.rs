use anyhow::Context;
use anyhow::Result;
use graphql_client::reqwest::post_graphql;
use graphql_client::GraphQLQuery;
use interprocess::local_socket::LocalSocketStream;
use log::info;
use lsp_types::Location;
use lsp_types::Url;
use reqwest::Client;

use crate::get_commit_hash;
use crate::uri_from_link;
use crate::RemoteFile;
use crate::RemoteFileMessage;
use crate::RemoteMessage;
use crate::CLIENT;

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
    // let remote_file = uri_from_link(&uri, get_commit_hash).await?;

    // TODO: Don't copy this so much
    let mut conn = LocalSocketStream::connect("/tmp/example.sock")?;

    let message = RemoteFileMessage { path: uri };
    let mut vec = vec![RemoteFileMessage::NAME.into()];
    vec.extend(message.args());

    info!("Starting val...");
    let val = rmpv::Value::Array(vec);
    rmpv::encode::write_value(&mut conn, &val)?;
    let response = rmpv::decode::read_value(&mut conn)?;
    let remote_file = if let rmpv::Value::Array(response) = response {
        info!("Inside of value unpacking");
        let remote = response[0].as_str().unwrap().to_string();
        let commit = response[1].as_str().unwrap().to_string();
        let path = response[2].as_str().unwrap().to_string();

        // TODO: Need to handle line and column, could be null

        RemoteFile {
            remote,
            commit,
            path,

            // TODO: Clean this up and do gud
            line: match response[3] {
                rmpv::Value::Integer(line) => Some(line.as_u64().unwrap() as usize),
                _ => None,
            },
            col: match response[4] {
                rmpv::Value::Integer(col) => Some(col.as_u64().unwrap() as usize),
                _ => None,
            },
        }
    } else {
        panic!("Can't do it")
    };

    let response_body = post_graphql::<DefinitionQuery, _>(
        &CLIENT,
        "https://sourcegraph.com/.api/graphql",
        definition_query::Variables {
            repository: remote_file.remote,
            revision: remote_file.commit,
            path: remote_file.path,
            line,
            character,
        },
    )
    .await?;

    info!("Got a responsew!");
    let nodes = response_body
        .data
        .context("definition.data")?
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
        let range = node.range.context("Missing range for some IDIOTIC reason??? ME???")?;

        let sg_url = format!("sg:/{}", node.url);

        let node_remote = uri_from_link(&sg_url, get_commit_hash).await?;
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
