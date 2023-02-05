use {
    crate::entry,
    anyhow::Result,
    sqlx::{Connection, SqlitePool},
    std::collections::HashSet,
    tokio::sync::OnceCell,
};

pub trait Executor<'a>: sqlx::Executor<'a, Database = sqlx::Sqlite> {}
impl<'a, T> Executor<'a> for T where T: sqlx::Executor<'a, Database = sqlx::Sqlite> {}

static INSTANCE: OnceCell<SqlitePool> = OnceCell::const_new();
pub async fn get_pool() -> &'static SqlitePool {
    INSTANCE
        .get_or_init(|| async {
            dotenv::dotenv().ok();

            let pool = SqlitePool::connect(std::env!("DATABASE_URL"))
                .await
                .expect("can open the program");

            sqlx::migrate!()
                .run(&pool)
                .await
                .expect("Migrations to complete successfully");

            pool
        })
        .await
}

pub async fn insert_remote_file<'a>(
    pool: impl Executor<'a>,
    file: crate::entry::File,
    contents: &str,
) -> Result<()> {
    sqlx::query!(
        "INSERT INTO remote_file (remote, oid, path, contents)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (remote, oid, path) DO
            UPDATE SET contents=$4",
        file.remote,
        file.oid,
        file.path,
        contents
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn get_remote_file_contents<'a>(file: &crate::entry::File) -> Result<Option<String>> {
    let pool = get_pool().await;

    Ok(sqlx::query!(
        "SELECT contents FROM remote_file WHERE remote=$1 AND oid=$2 AND path=$3",
        file.remote,
        file.oid,
        file.path
    )
    .fetch_optional(pool)
    .await?
    .map(|x| x.contents))
}

pub async fn bulk_insert_contents(triplets: HashSet<(String, String, String)>) -> Result<()> {
    // this kind of a lie LUL
    let mut conn = get_pool().await.acquire().await?;
    let mut transaction = conn.begin().await?;

    // BEWARE sqlite specific
    sqlx::query!(
        "CREATE TABLE temp.triplet (remote TEXT NOT NULL, oid TEXT NOT NULL, path NOT NULL);"
    )
    .execute(&mut transaction)
    .await?;

    // TODO: Think about maybe a better way to do bulk insert these, but it's OK, it will just be
    // up to thousands of triplets.
    // TODO: Maybe prepare the statement?
    for triplet in triplets {
        sqlx::query("INSERT INTO temp.triplet (remote, oid, path) VALUES ($1, $2, $3);")
            .bind(triplet.0)
            .bind(triplet.1)
            .bind(triplet.2)
            .execute(&mut transaction)
            .await?;
    }

    let missing = sqlx::query_as::<_, (String, String, String)>(
        "select remote, oid, path from temp.triplet except select remote, oid, path from remote_file"
        ).fetch_all(&mut transaction).await?;

    for miss in missing {
        let file = entry::File {
            remote: entry::Remote(miss.0),
            oid: entry::OID(miss.1),
            path: miss.2,
            position: entry::Position::default(),
        };

        let contents =
            crate::get_remote_file_contents(&file.remote.0, &file.oid.0, &file.path).await?;
        insert_remote_file(&mut transaction, file, &contents).await?;
    }

    transaction.commit().await?;

    Ok(())
}
