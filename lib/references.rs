use {anyhow::Result, lsp_types::Location};

// #[derive(GraphQLQuery)]
// #[graphql(
//     schema_path = "gql/schema.graphql",
//     query_path = "gql/references_query.graphql",
//     response_derives = "Debug"
// )]
// pub struct ReferencesQuery;

pub async fn get_references(uri: String, line: i64, character: i64) -> Result<Vec<Location>> {
    // let remote_file = entry::Entry::new(&uri).await?;
    // let remote_file = match remote_file {
    //     entry::Entry::File(file) => file,
    //     _ => return Err(anyhow::anyhow!("Can only get references of a file")),
    // };
    //
    // info!("Remote File: {:?}", remote_file);
    // let response_body = get_graphql::<ReferencesQuery>(references_query::Variables {
    //     repository: remote_file.remote.0,
    //     revision: remote_file.oid.0,
    //     path: remote_file.path,
    //     line,
    //     character,
    // })
    // .await?;
    //
    // let nodes = response_body
    //     .repository
    //     .context("repository")?
    //     .commit
    //     .context("commit")?
    //     .blob
    //     .context("blob")?
    //     .lsif
    //     .context("lsif")?
    //     .references
    //     .nodes;
    //
    // let mut triplets: HashSet<(String, String, String)> = HashSet::new();
    // let mut references: Vec<Location> = Vec::new();
    // for node in nodes {
    //     triplets.insert((
    //         node.resource.repository.name.clone(),
    //         node.resource.commit.oid.clone(),
    //         node.resource.path.clone(),
    //     ));
    //
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
    //     references.push(file.try_into()?);
    // }
    //
    // // TODO: Get every remote, oid, path combination
    // // Request all the contents in one request that we're missing
    // // Update database with the contents of those files
    // // crate::db::bulk_insert_contents(triplets).await?;
    //
    // Ok(references)
    todo!()
}
