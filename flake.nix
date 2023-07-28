{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-nix.url = "github:cachix/pre-commit-hooks.nix";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
    nixpkgs-latest-vimplugins.url = "github:nixos/nixpkgs";
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
          inherit (self.packages.${prev.system}) sg-nvim;
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
            (final: prev: {
              # NOTE: use legacyPackages to prevent importing everything on latest nixpkgs
              # we should use this because we all know teej develops against
              # latest Plenary
              vimPlugins = inputs.nixpkgs-latest-vimplugins.legacyPackages.${system}.vimPlugins;
            })
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
        # for parallel along with our overlay
        packages.sg-nvim = self'.packages.all;

        packages.neovim-with-sg = let
          inherit (self'.packages) sg-nvim;
          plug = pkgs.vimPlugins;
          cfg = pkgs.neovimUtils.makeNeovimConfig {
            withNodeJs = true;
            plugins = [
              {plugin = plug.plenary-nvim;}
              {plugin = sg-nvim;}
              {plugin = plug.nvim-treesitter.withPlugins (ts: [ts.lua ts.typescript]);}
            ];
            # TODO: alternative way is to add to LUA_CPATH, correctness unknown.
            customRC = ''
              lua <<EOF
              package.cpath = package.cpath .. ";${sg-nvim}/lib/*.so;${sg-nvim}/lib/*.dylib"
              EOF
            '';
            # `-u` sucks, it skips a lot of things that prevents `-l` to go
            # on happy route. We will instead use `$VIMINIT` for sandboxed neovim
            # even in the impure shell
            wrapRc = false;
          };
          vimrc-drv = pkgs.writeTextFile {
            name = "init.vim";
            text = cfg.neovimRcContent;
          };
          cfg-set-viminit =
            cfg
            // {
              wrapperArgs =
                (pkgs.lib.escapeShellArgs cfg.wrapperArgs)
                + " "
                + "--set VIMINIT \':source ${vimrc-drv}\'"
                + " "
                + ''--suffix PATH : "${pkgs.lib.makeBinPath [self'.packages.sg-nvim]}"''
                # + ''--add-flags '--cmd "lua vim.v.progpath=\'$0\'"' ''
                # + (pkgs.lib.escapeShellArgs ["--add-flags" "--cmd \"lua vim.v.progpath='$0'\""])
                # + " "
                # + (pkgs.lib.escapeShellArgs ["--add-flags" "--cmd \"lua print('$0')\""])
                # + " "
                # + (pkgs.lib.escapeShellArgs ["--add-flags" "--cmd \"lua print(vim.v.progpath)\""])
                ;
            };
        in
          pkgs.wrapNeovimUnstable pkgs.neovim.unwrapped cfg-set-viminit;

        apps.neovim-with-sg = {
          type = "app";
          program = self'.packages.neovim-with-sg;
        };
        apps.default = self'.apps.neovim-with-sg;

        checks.unit-test = let
          inherit (self'.packages) neovim-with-sg;
        in
          pkgs.runCommand "script-test.lua.out" {} ''
            ${neovim-with-sg}/bin/nvim --version >$out
          '';

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
