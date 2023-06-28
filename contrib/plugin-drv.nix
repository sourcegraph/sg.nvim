{
  pkgs,
  stdenv,
  proj_root ? ./.,
  meta ? (pkgs.callPackage (import ./meta.nix)),
  ...
}:
stdenv.mkDerivation {
  name = "sg.nvim-plugin";
  src = proj_root;
  phases = ["installPhase"];
  installPhase = ''
    mkdir -p $out
    cp -r $src/{lua,plugin} $out
  '';
  inherit meta;
}
