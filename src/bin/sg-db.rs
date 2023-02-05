use {anyhow::Result, sg::db::bulk_insert_contents, std::collections::HashSet};

#[tokio::main]
async fn main() -> Result<()> {
    dotenv::dotenv().ok();

    let mut triplets = HashSet::new();
    triplets.insert((
        "github.com/sourcegraph/sourcegraph".to_string(),
        "1f91c9fdb5fa683b868ca7cd0f90f000e34d42b1".to_string(),
        "README.md".to_string(),
    ));

    bulk_insert_contents(triplets).await?;

    Ok(())
}
