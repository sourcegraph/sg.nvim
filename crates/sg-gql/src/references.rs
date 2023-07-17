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
        query_path = "gql/references_query.gql",
        response_derives = "Debug"
    )]
    pub struct ReferencesQuery;
}

pub use private::{references_query::Variables, ReferencesQuery as Query};
use {
    crate::make_bufname,
    lsp_types::{Location, Position, Url},
};

pub async fn request(
    client: &reqwest::Client,
    endpoint: String,
    variables: Variables,
) -> Result<Vec<Location>> {
    let response = crate::get_graphql::<Query>(client, endpoint, variables).await?;

    let nodes = response
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

    // let mut triplets: HashSet<(String, String, String)> = HashSet::new();
    let mut references: Vec<Location> = Vec::new();
    for node in nodes {
        // triplets.insert((
        //     node.resource.repository.name.clone(),
        //     node.resource.commit.oid.clone(),
        //     node.resource.path.clone(),
        // ));
        let range = node.range.context("Must have range")?;

        let position = Position::new(range.start.line as u32, range.start.character as u32);
        let remote: Remote = node.resource.repository.name.into();
        let oid: OID = node.resource.commit.oid.into();
        let path = node.resource.path;

        let location = Location {
            uri: Url::parse(&make_bufname(&remote, &oid, &path))?,
            range: lsp_types::Range {
                start: position,
                end: position,
            },
        };

        references.push(location);
    }

    // TODO: Get every remote, oid, path combination
    // Request all the contents in one request that we're missing
    // Update database with the contents of those files
    // crate::db::bulk_insert_contents(triplets).await?;

    Ok(references)
}
