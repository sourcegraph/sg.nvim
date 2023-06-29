use {
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    reqwest::Client,
};

pub mod cody_completion;
pub mod commit_oid;
pub mod embeddings_context;
pub mod file;
pub mod hover;
pub mod list_files;
pub mod path_info;
pub mod repository_id;

pub async fn get_graphql<Q: GraphQLQuery>(
    client: &Client,
    endpoint: String,
    variables: Q::Variables,
) -> Result<Q::ResponseData> {
    let vars_ser = serde_json::to_string(&variables)?;
    let response = match post_graphql::<Q, _>(client, endpoint, variables).await {
        Ok(response) => response,
        Err(err) => {
            return Err(anyhow::anyhow!(
                "Failed with (OH NO) status: {:?} || {err:?} TESTING: {}",
                err.status(),
                vars_ser
            ))
        }
    };

    if let Some(errors) = response.errors {
        return Err(anyhow::anyhow!("Errors in response: {:?}", errors));
    }

    response.data.context("get_graphql -> data")
}
