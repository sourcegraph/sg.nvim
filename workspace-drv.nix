{
  pkgs,
  lib,
  craneLib, # TODO: Make this flakes-free
  pkg-config,
  openssl,
  stdenv,
  darwin,
  proj_root ? ./.,
  meta ? (pkgs.callPackage (import ./meta.nix)),
  ...
}: let
  # PURPOSE: if you modify non-code like github workflows, nix should not trigger a rebuild.
  # cleanCargoSource works as a white-list only filter that keeps `.rs` and `.toml`
  # NOTE: if you use `include!(<file>)` in Rust code. You'll have to opt-in the file
  # using a custom filter. See https://github.com/ipetkov/crane/blob/master/lib/filterCargoSources.nix
  code_artifacts =
    lib.cleanSourceWith
    {
      src = lib.cleanSource proj_root;
      filter = orig_path: type: let
        path = toString orig_path;
        base = baseNameOf path;
        parentDir = baseNameOf (dirOf path);

        matchesSuffix = lib.any (suffix: lib.hasSuffix suffix base) [
          # Keep rust sources
          ".rs"

          # Rust configs
          "Cargo.toml"
          "config.toml"

          ".gql"
          ".graphql"
        ];

        # Cargo.toml already captured above
        isCargoFile = base == "Cargo.lock";

        # .cargo/config.toml already captured above
        isCargoConfig = parentDir == ".cargo" && base == "config";
      in
        type == "directory" || matchesSuffix || isCargoFile || isCargoConfig;
    };

  crane-args = {
    pname = "sg.nvim-workspace";
    version = (with builtins; fromTOML (readFile "${proj_root}/Cargo.toml")).package.version or "unknown";
    src = code_artifacts;

    nativeBuildInputs = [pkg-config];

    # openssl: required by reqwest (-> hyper-tls -> native-tls)
    buildInputs =
      [openssl]
      ++ (lib.optional stdenv.isDarwin [
        darwin.apple_sdk.frameworks.Security
      ]);
    inherit meta;
  };

  # PURPOSE: This attempts to reuse build cache to skip having to build dependencies
  workspace-deps = craneLib.buildDepsOnly crane-args;

  workspace-all = craneLib.buildPackage (crane-args
    // {
      cargoArtifacts = workspace-deps;
    });
in
  workspace-all
