use {anyhow::Result, graphql_client::GraphQLQuery};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/user_query.gql",
        response_derives = "Debug"
    )]
    pub struct UserQuery;
}

pub use private::{user_query::Variables, UserQuery as Query};
use {
    anyhow::Context,
    serde::{Deserialize, Serialize},
};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct UserInfo {
    pub id: String,
    pub username: String,
    pub cody_pro_enabled: bool,
}

pub async fn request(
    client: &reqwest::Client,
    endpoint: String,
    variables: Variables,
) -> Result<UserInfo> {
    crate::get_graphql::<Query>(client, endpoint, variables)
        .await
        .and_then(|response_body| {
            let user = response_body.current_user.context("no current user")?;

            Ok(UserInfo {
                id: user.id,
                username: user.username,
                cody_pro_enabled: user.cody_pro_enabled,
            })
        })
}
