{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-nix.url = "github:cachix/pre-commit-hooks.nix";
    rust-overlay.url = "github:oxalica/rust-overlay";
    nci.url = "github:yusdacra/nix-cargo-integration";
  };

  outputs = {
    self,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.nci.flakeModule
        inputs.pre-commit-nix.flakeModule
      ];

      systems = ["x86_64-darwin" "x86_64-linux" "aarch64-darwin" "aarch64-linux"];
      perSystem = {
        config,
        lib,
        pkgs,
        self',
        ...
      }: let
        inherit (config.nci) outputs;
        withOpenSSL = {
          mkDerivation = {
            nativeBuildInputs = with pkgs; [pkg-config];
            buildInputs = with pkgs; [openssl] ++ lib.optionals pkgs.stdenv.isDarwin [darwin.apple_sdk.frameworks.Security];
          };
        };
      in {
        nci = {
          toolchainConfig = ./rust-toolchain.toml;
          projects."sg.nvim" = {
            path = ./.;
            drvConfig = withOpenSSL;
            depsDrvConfig = withOpenSSL;
          };

          crates = {
            jsonrpc = {};
            sg-gql = {};
            sg-types = {};
            sg = {};
          };
        };

        devShells.default = outputs."sg.nvim".devShell;
        packages = {
          default = outputs.sg.packages.release;
          sg-nvim = pkgs.vimUtils.buildVimPlugin {
            name = "sg.nvim";
            inherit (self'.packages.default) version;
            src = ./.;
            propagatedBuildInputs = [self'.packages.default];
            # Some package managers, like lazy.nvim, have some nifty features that depend on plugin directories being full fledged git repositories.
            # So we'll leave .git lying around just for them :)
            leaveDotGit = true;
          };
        };

        pre-commit = {
          settings = {
            hooks.alejandra.enable = true;
            hooks.rustfmt.enable = true;
            hooks.cargo-check.enable = true;
          };
        };
      };
    };
}
