use std::collections::HashMap;
use std::sync::Mutex;

use anyhow::Context;
use anyhow::Result;
use graphql_client::reqwest::post_graphql;
use graphql_client::GraphQLQuery;
use once_cell::sync::OnceCell;

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.gql",
    query_path = "gql/get_file_query.gql",
    response_derives = "Debug"
)]
pub struct GetFileQuery;

type FileMap = Mutex<HashMap<(String, String), Vec<String>>>;
pub fn get_file_map() -> &'static FileMap {
    static INSTANCE: OnceCell<FileMap> = OnceCell::new();
    INSTANCE.get_or_init(|| Mutex::new(HashMap::new()))
}

// TODO: Once I understand how I could actually return this... we could stop copying.
pub async fn get_files(repository: String, commit: String) -> Result<Vec<String>> {
    let client = crate::get_client()?;
    let response_body = post_graphql::<GetFileQuery, _>(
        &client,
        "https://sourcegraph.com/.api/graphql",
        get_file_query::Variables {
            name: repository,
            rev: commit,
        },
    )
    .await?;

    let result = response_body
        .data
        .context("No data")?
        .repository
        .context("No matching repository found")?
        .commit
        .context("No matching commit found")?
        .file_names;

    Ok(result)
}
