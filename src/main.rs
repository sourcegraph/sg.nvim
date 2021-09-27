use std::error::Error;

use sg;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
  let x = sg::uri_from_link(
    "https://sourcegraph.com/github.com/neovim/neovim/-/blob/src/nvim/autocmd.c",
    sg::get_commit_hash,
  )
  .await?;

  println!("Hello, world! {} -> {}", x.remote, x.commit);

  Ok(())
}
