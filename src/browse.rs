use anyhow::{anyhow, Result};
use gix::url::Url;
use gix::{remote, Repository};

pub(crate) fn current_rev(repo: &Repository) -> Result<String> {
    match repo.head()?.kind {
        gix::head::Kind::Symbolic(r) => Ok(r.name.to_string()),
        gix::head::Kind::Detached { target, .. } => Ok(target.to_string()),
        gix::head::Kind::Unborn(_) => Err(anyhow!("pointing to an uninitialized repo")),
    }
}

pub(crate) fn get_repo_name(repo: &Repository) -> Result<String> {
    let remote_url = read_remote_url(repo)?;
    let name = extract_repo_name(&remote_url)?;
    Ok(name)
}

fn extract_repo_name(remote_url: &Url) -> Result<String> {
    let git_host = remote_url.host().ok_or(anyhow!("remote has no host"))?;
    let path = remote_url.path.to_string();
    let path = path.trim_end_matches(".git");

    Ok(format!("{git_host}/{path}"))
}

fn read_remote_url(repo: &Repository) -> Result<Url> {
    let default_remote = repo
        .find_default_remote(remote::Direction::Push)
        .ok_or(anyhow!("no default repo"))??;
    Ok(default_remote
        .url(remote::Direction::Push)
        .ok_or(anyhow!("no default repo"))?
        .clone())
}
