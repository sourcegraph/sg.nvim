use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
    reqwest::Client,
    sg_types::{Remote, OID},
};

pub mod cody_completion;
pub mod commit_oid;
pub mod definition;
pub mod dotcom_user;
pub mod embeddings_context;
pub mod enterprise_user;
pub mod file;
pub mod hover;
pub mod list_files;
pub mod path_info;
pub mod references;
pub mod search;
pub mod sourcegraph_version;

async fn post_graphql<Q: GraphQLQuery, U: reqwest::IntoUrl>(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    url: U,
    variables: Q::Variables,
) -> Result<graphql_client::Response<Q::ResponseData>> {
    let body = Q::build_query(variables);

    let reqwest_response = client.post(url).headers(headers).json(&body).send().await?;

    reqwest_response
        .json()
        .await
        .context("post_graphql -> json")
}

pub async fn get_graphql<Q: GraphQLQuery>(
    client: &Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Q::Variables,
) -> Result<Q::ResponseData> {
    let vars_ser = serde_json::to_string(&variables)?;
    let response = match post_graphql::<Q, _>(client, headers, endpoint, variables).await {
        Ok(response) => response,
        Err(err) => {
            return Err(anyhow::anyhow!(
                "Graphql failed with status:\n{err:?}\nvars: {vars_ser}",
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
