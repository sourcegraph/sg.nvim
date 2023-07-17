use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
};

pub(super) mod private {
    use super::*;

    #[derive(GraphQLQuery)]
    #[graphql(
        schema_path = "gql/schema.gql",
        query_path = "gql/search.gql",
        response_derives = "Debug"
    )]
    pub struct SearchQuery;
}

pub use private::{search_query::Variables, SearchQuery as Query};
use sg_types::SearchResult;

pub async fn request(
    client: &reqwest::Client,
    endpoint: String,
    variables: Variables,
) -> Result<Vec<SearchResult>> {
    use private::search_query::SearchQuerySearchResultsResults::*;
    let response = crate::get_graphql::<Query>(client, endpoint, variables).await?;

    let results = response.search.context("search")?.results.results;

    let mut matches = vec![];
    for result in results {
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

                for symbol in m.symbols {
                    let line = match &symbol.location.range {
                        Some(range) => range.start.line as usize,
                        None => continue,
                    };

                    matches.push(SearchResult {
                        repo: m.repository.name.clone(),
                        file: m.file.path.clone(),
                        preview: symbol.name,
                        line,
                    });
                }
            }
            CommitSearchResult => continue,
            Repository => continue,
        }
    }

    Ok(matches)
}
