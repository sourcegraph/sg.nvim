{
  pkgs,
  symlinkJoin,
  sg-workspace ? (pkgs.callPackage (import ./workspace-drv.nix)),
  sg-plugin ? (pkgs.callPackage (import ./plugin-drv.nix)),
  meta ? (pkgs.callPackage (import ./meta.nix)),
  ...
}:
symlinkJoin {
  name = "sg.nvim";
  paths = [sg-workspace sg-plugin];
  inherit meta;
}
