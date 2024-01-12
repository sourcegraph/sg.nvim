use {anyhow::Result, graphql_client::GraphQLQuery};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/enterprise_user_query.gql",
        response_derives = "Debug"
    )]
    pub struct EnterpriseUserQuery;
}

pub use private::{enterprise_user_query::Variables, EnterpriseUserQuery as Query};
use {crate::dotcom_user::UserInfo, anyhow::Context};

pub async fn request(
    client: &reqwest::Client,
    headers: reqwest::header::HeaderMap,
    endpoint: String,
    variables: Variables,
) -> Result<UserInfo> {
    crate::get_graphql::<Query>(client, headers, endpoint, variables)
        .await
        .and_then(|response_body| {
            let user = response_body.current_user.context("no current user")?;

            Ok(UserInfo {
                id: user.id,
                username: user.username,
                cody_pro_enabled: user.cody_pro_enabled,
                code_usage: None,
                code_limit: None,
                chat_usage: None,
                chat_limit: None,
                completion_override: None,
                code_override: None,
            })
        })
}
