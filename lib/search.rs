use {
    crate::CLIENT,
    anyhow::{Context, Result},
    graphql_client::{reqwest::post_graphql, GraphQLQuery},
    lsp_types::Location,
};

#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "gql/schema.graphql",
    query_path = "gql/search.graphql",
    response_derives = "Debug"
)]
pub struct SearchQuery;

#[derive(Debug)]
pub struct SearchResult {
    pub repo: String,
    pub file: String,
    pub preview: String,
    pub line: usize,
}

pub async fn get_search(query: &str) -> Result<Vec<SearchResult>> {
    let query = query.to_string();

    let response_body = post_graphql::<SearchQuery, _>(
        &CLIENT,
        "https://sourcegraph.com/.api/graphql",
        search_query::Variables { query },
    )
    .await?;

    let results = response_body
        .data
        .context("data")?
        .search
        .context("search")?
        .results
        .results;

    let mut matches = vec![];
    for result in results {
        use search_query::SearchQuerySearchResultsResults::*;
        // for m in result
        // println!("{result:?}");

        match result {
            FileMatch(m) => {
                for line in m.line_matches {
                    matches.push(SearchResult {
                        repo: m.repository.name.clone(),
                        file: m.file.path.clone(),
                        preview: line.preview,
                        line: line.line_number as usize,
                    });
                }
            }
            CommitSearchResult => continue,
            Repository => continue,
        }
    }

    Ok(matches)
}
