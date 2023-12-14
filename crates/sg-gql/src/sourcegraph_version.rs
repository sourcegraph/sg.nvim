use {anyhow::Result, graphql_client::GraphQLQuery, sg_types::SourcegraphVersion};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/version_query.gql",
        response_derives = "Debug"
    )]
    pub struct VersionQuery;
}

pub use private::{version_query::Variables, VersionQuery as Query};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<SourcegraphVersion> {
    crate::get_graphql::<Query>(client, headers, endpoint, variables)
        .await
        .map(|response_body| {
            let version = response_body.site;
            SourcegraphVersion {
                product: version.product_version,
                build: version.build_version,
            }
        })
}
