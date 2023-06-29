use {
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    reqwest::Client,
    sg_types::{Remote, OID},
};

pub mod cody_completion;
pub mod commit_oid;
pub mod definition;
pub mod embeddings_context;
pub mod file;
pub mod hover;
pub mod list_files;
pub mod path_info;
pub mod references;
pub mod repository_id;
pub mod search;
pub mod sourcegraph_version;

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

// TODO: This is copied, should put this somewhere else
pub(crate) fn make_bufname(remote: &Remote, oid: &OID, path: &str) -> String {
    format!("sg://{}@{}/-/{}", remote.shortened(), oid.shortened(), path)
}
