use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
    sg_types::*,
};

mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/definition_query.gql",
        response_derives = "Debug"
    )]
    pub struct DefinitionQuery;

    // TODO: Consider what we want to do for search definitions.
    //  I don't necessarily care to support them at the moment?
    // #[derive(GraphQLQuery)]
    // #[graphql(
    //     schema_path = "gql/schema.gql",
    //     query_path = "gql/search_definition_query.gql",
    //     response_derives = "Debug"
    // )]
    // pub struct SearchDefinitionQuery;
}

pub use private::{definition_query::Variables, DefinitionQuery as Query};
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

        definitions.push(location)
    }

    Ok(definitions)
}
