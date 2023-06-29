use {anyhow::Result, lsp_types::Location};

// #[derive(GraphQLQuery)]
// #[graphql(
//     schema_path = "gql/schema.graphql",
//     query_path = "gql/definition_query.graphql",
//     response_derives = "Debug"
// )]
// pub struct DefinitionQuery;

// #[derive(GraphQLQuery)]
// #[graphql(
//     schema_path = "gql/schema.graphql",
//     query_path = "gql/search_definition_query.graphql",
//     response_derives = "Debug"
// )]
// pub struct SearchDefinitionQuery;

pub async fn get_definitions(uri: String, line: i64, character: i64) -> Result<Vec<Location>> {
    // // TODO: Could put the line and character in here directly as well...
    // let remote_file = entry::Entry::new(&uri).await?;
    // let remote_file = match remote_file {
    //     entry::Entry::File(file) => file,
    //     _ => return Err(anyhow::anyhow!("Can only get references of a file")),
    // };
    //
    // info!("Remote File: {:?}", remote_file);
    //
    // let response_body = get_graphql::<DefinitionQuery>(definition_query::Variables {
    //     repository: remote_file.remote.0,
    //     revision: remote_file.oid.0,
    //     path: remote_file.path,
    //     line,
    //     character,
    // })
    // .await?;
    //
    // info!("Got a responsew!");
    // let nodes = response_body
    //     .repository
    //     .context("No matching repository")?
    //     .commit
    //     .context("No matching commit")?
    //     .blob
    //     .context("No matching blob")?
    //     .lsif
    //     .context("No corresponding code intelligence")?
    //     .definitions
    //     .nodes;
    //
    // let mut definitions: Vec<Location> = Vec::new();
    // for node in nodes {
    //     let range = node.range.context("Must have range")?;
    //     let file = entry::Entry::File(entry::File {
    //         remote: node.resource.repository.name.into(),
    //         oid: node.resource.commit.oid.into(),
    //         path: node.resource.path,
    //         position: entry::Position {
    //             line: Some(range.start.line as usize),
    //             col: Some(range.start.character as usize),
    //         },
    //     });
    //
    //     definitions.push(file.try_into()?)
    // }
    //
    // Ok(definitions)
    todo!()
}
