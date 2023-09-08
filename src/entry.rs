use {
    crate::{get_path_info, normalize_url, PathInfo},
    anyhow::{Context, Result},
    gix::discover,
    regex::Regex,
    serde::{Deserialize, Serialize},
    sg_types::*,
    std::{path::PathBuf, str::FromStr},
};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Entry {
    File(File),
    Directory(Directory),
    Repo(Repo),
}

impl Entry {
    pub async fn new(uri: &str) -> Result<Self> {
        if !uri.starts_with("sg://") && !uri.starts_with("https://") {
            return Self::from_local_path(uri).await;
        }

        let uri = normalize_url(uri);
        let (remote_with_commit, path) = match uri.split_once("/-/") {
            Some(split) => split,
            None => {
                let uri = uri.to_string();
                let (remote, oid) = uri.split_once('@').unwrap_or((&uri, "HEAD"));

                // Handle the repo case here.
                return Ok(Self::Repo(Repo {
                    remote: remote.to_string().into(),
                    oid: oid.to_string().into(),
                }));
            }
        };

        if path.is_empty() {
            todo!("Handled repos, not files")
        }

        let (remote, commit) = remote_with_commit
            .split_once('@')
            .unwrap_or((remote_with_commit, "HEAD"));

        let prefix_regex = Regex::new("^(blob|tree)/")?;
        let path = prefix_regex.replace(path, "").to_string();

        // TODO: Not sure if you can have question marks in filepaths for github...
        //      Will need to test that out later
        let (path, _) = path.split_once('?').unwrap_or((&path, ""));

        let info = get_path_info(remote.to_string(), commit.to_string(), path.to_string()).await?;
        Self::from_info(info)
    }

    pub async fn from_local_path(path: &str) -> Result<Self> {
        let path = PathBuf::from_str(path)?;
        let dir = path.parent().context("Valid parent for path")?;
        let repo = discover(dir).context("Discover repo")?;
        let repo_name = link::get_repo_name(&repo)?;
        let revision = link::current_rev(&repo)?;
        let path = path.strip_prefix(repo.work_dir().context("Working directory")?)?;
        let info = get_path_info(repo_name, revision, path.to_str().unwrap().to_owned()).await?;

        Self::from_info(info)
    }

    pub fn typename(&self) -> &'static str {
        match self {
            Entry::File(_) => "file",
            Entry::Directory(_) => "directory",
            Entry::Repo(_) => "repo",
        }
    }

    pub fn from_info(info: PathInfo) -> Result<Self> {
        let PathInfo {
            remote,
            oid,
            path,
            is_directory,
        } = info;

        if is_directory {
            Ok(Self::Directory(Directory {
                remote: remote.parse()?,
                oid: oid.parse()?,
                path,
            }))
        } else {
            // let position = {
            //     // TODO: We could probably handle a few more cases here :)
            //     let arg_split: Vec<&str> = args.split(':').collect();
            //
            //     if arg_split.len() == 2 {
            //         Position {
            //             line: Some(arg_split[0][1..].parse().unwrap_or(1)),
            //             col: Some(arg_split[1].parse().unwrap_or(1)),
            //         }
            //     } else if arg_split.len() == 1 {
            //         match arg_split[0][1..].parse() {
            //             Ok(val) => Position {
            //                 line: Some(val),
            //                 col: None,
            //             },
            //             Err(_) => Position::default(),
            //         }
            //     } else {
            //         Position::default()
            //     }
            // };
            let position = Position::default();

            Ok(Self::File(File {
                remote: remote.parse()?,
                oid: oid.parse()?,
                path,
                position,
            }))
        }
    }

    pub fn bufname(&self) -> String {
        match self {
            Entry::File(file) => file.bufname(),
            Entry::Directory(dir) => dir.bufname(),
            Entry::Repo(repo) => repo.bufname(),
        }
    }

    fn position(&self) -> Option<Position> {
        match self {
            Entry::File(file) => Some(file.position.clone()),
            Entry::Directory(_) => None,
            Entry::Repo(_) => None,
        }
    }
}

impl std::convert::TryFrom<Entry> for lsp_types::Location {
    type Error = anyhow::Error;

    fn try_from(value: Entry) -> Result<Self, Self::Error> {
        use lsp_types::Url;

        let position = match value.position() {
            Some(Position {
                line: Some(line),
                col: Some(col),
            }) => lsp_types::Position::new(line as u32, col as u32),
            Some(Position {
                line: Some(line),
                col: None,
            }) => lsp_types::Position::new(line as u32, 0),
            _ => lsp_types::Position::default(),
        };

        Ok(Self {
            uri: Url::parse(&value.bufname())?,
            range: lsp_types::Range {
                start: position,
                end: position,
            },
        })
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Position {
    pub line: Option<usize>,
    pub col: Option<usize>,
}

fn make_bufname(remote: &Remote, oid: &OID, path: Option<&str>) -> String {
    match path {
        Some(path) => format!("sg://{}@{}/-/{}", remote.shortened(), oid.shortened(), path),
        None => format!("sg://{}@{}", remote.shortened(), oid.shortened()),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct File {
    pub remote: Remote,
    pub oid: OID,
    pub path: String,
    pub position: Position,
}

impl File {
    pub fn bufname(&self) -> String {
        make_bufname(&self.remote, &self.oid, Some(&self.path))
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Directory {
    pub remote: Remote,
    pub oid: OID,
    pub path: String,
}

impl Directory {
    pub fn bufname(&self) -> String {
        make_bufname(&self.remote, &self.oid, Some(&self.path))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Repo {
    pub remote: Remote,
    pub oid: OID,
}

impl Repo {
    fn bufname(&self) -> String {
        make_bufname(&self.remote, &self.oid, None)
    }
}

mod link {
    use {
        anyhow::{anyhow, Result},
        gix::{remote::Direction, Repository, Url},
    };

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
            .find_default_remote(Direction::Push)
            .ok_or(anyhow!("no default repo"))??;
        Ok(default_remote
            .url(Direction::Push)
            .ok_or(anyhow!("no default repo"))?
            .clone())
    }
}
