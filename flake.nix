{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-nix.url = "github:cachix/pre-commit-hooks.nix";
    rust-overlay.url = "github:oxalica/rust-overlay";
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
      };

      systems = ["x86_64-darwin" "x86_64-linux" "aarch64-darwin"];
      perSystem = {
        config,
        system,
        inputs',
        ...
      }: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            inputs.rust-overlay.overlays.default
          ];
        };
        toolchain = pkgs.rust-bin.fromRustupToolchainFile ./.rust-toolchain;
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

        packages.default = pkgs.callPackage ./. {inherit toolchain;};

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
