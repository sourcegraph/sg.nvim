use {
    anyhow::{Context, Result},
    graphql_client::GraphQLQuery,
};

// #[derive(GraphQLQuery)]
// #[graphql(
//     schema_path = "gql/schema.graphql",
//     query_path = "gql/search.graphql",
//     response_derives = "Debug"
// )]
// pub struct SearchQuery;

#[derive(Debug)]
pub struct SearchResult {
    pub repo: String,
    pub file: String,
    pub preview: String,
    pub line: usize,
}

pub async fn get_search(query: &str) -> Result<Vec<SearchResult>> {
    // use search_query::SearchQuerySearchResultsResults::*;
    //
    // let query = query.to_string();
    //
    // let response_body = get_graphql::<SearchQuery>(search_query::Variables { query }).await?;
    // let results = response_body.search.context("search")?.results.results;
    //
    // let mut matches = vec![];
    // for result in results {
    //     // println!("{result:?}");
    //     match result {
    //         FileMatch(m) => {
    //             for line in m.line_matches {
    //                 matches.push(SearchResult {
    //                     repo: m.repository.name.clone(),
    //                     file: m.file.path.clone(),
    //                     preview: line.preview,
    //                     line: line.line_number as usize,
    //                 });
    //             }
    //
    //             for symbol in m.symbols {
    //                 let line = match &symbol.location.range {
    //                     Some(range) => range.start.line as usize,
    //                     None => continue,
    //                 };
    //
    //                 matches.push(SearchResult {
    //                     repo: m.repository.name.clone(),
    //                     file: m.file.path.clone(),
    //                     preview: symbol.name,
    //                     line,
    //                 });
    //             }
    //         }
    //         CommitSearchResult => continue,
    //         Repository => continue,
    //     }
    // }
    //
    // Ok(matches)
    todo!()
}
