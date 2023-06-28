{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-nix.url = "github:cachix/pre-commit-hooks.nix";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
  };

  outputs = {
    self,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.pre-commit-nix.flakeModule
      ];

      flake = {
        overlays.default = final: prev: {
          sg-nvim = self.packages."${prev.system}".default;
        };
        # HACK: both nixpkgs.lib and pkgs.lib contain licenses
        # Technically impossible to do `callPackage` without proper `${system}`
        meta = import ./contrib/meta.nix {inherit (inputs.nixpkgs) lib;};
      };

      systems = ["x86_64-darwin" "x86_64-linux" "aarch64-darwin"];
      perSystem = {
        config,
        system,
        inputs',
        self',
        ...
      }: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.rust-overlay.overlays.default
          ];
        };
        toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      in {
        devShells.default = pkgs.mkShell {
          name = "sg.nvim";
          buildInputs = with pkgs; [
            openssl
            pkg-config
            toolchain
          ];
          shellHook = ''
            ${config.pre-commit.installationScript}
          '';
        };

        formatter = pkgs.alejandra;

        packages.workspace = pkgs.callPackage ./contrib/workspace-drv.nix {
          craneLib = inputs.crane.lib.${system}.overrideToolchain toolchain;
          proj_root = inputs.self;
          inherit (self) meta;
        };

        packages.plugin = pkgs.callPackage ./contrib/plugin-drv.nix {
          proj_root = inputs.self;
          inherit (self) meta;
        };

        packages.all = pkgs.callPackage ./contrib/default.nix {
          sg-workspace = self'.packages.workspace;
          sg-plugin = self'.packages.plugin;
          inherit (self) meta;
        };

        packages.default = self'.packages.all;

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
