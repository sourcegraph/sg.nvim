{
  pkgs ? (import <nixpkgs> {}),
  symlinkJoin ? pkgs.symlinkJoin,
  sg-workspace ? (pkgs.callPackage (import ./workspace-drv.nix)),
  sg-plugin ? (pkgs.callPackage (import ./plugin-drv.nix)),
  meta ? (pkgs.callPackage (import ./meta.nix)),
  ...
}: let
  sg-nvim = symlinkJoin {
    name = "sg.nvim";
    paths = [sg-workspace sg-plugin];
    inherit meta;
  };
in
  sg-nvim
  // {
    # provides quick access if we're using home-manager
    hm-vimPlugin = {
      plugin = sg-nvim;
      config = ''
        package.cpath = package.cpath .. ";${sg-nvim}/lib/*.so;${sg-nvim}/lib/*.dylib"
      '';
      type = "lua";
    };
  }
