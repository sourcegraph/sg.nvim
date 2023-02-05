-- Add migration script here

CREATE TABLE remote_file (
  remote TEXT NOT NULL,
  oid TEXT NOT NULL,
  path TEXT NOT NULL,
  contents TEXT NOT NULL,

  -- Add unique constraint on remote, oid and path
  UNIQUE(remote, oid, path)
);
