{
  lib,
  rustPlatform,
  toolchain,
  pkg-config,
  openssl,
  stdenv,
  darwin,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "sg.nvim";
  version = "0.1.0";

  src = ./.;
  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [pkg-config toolchain];
  buildInputs = [openssl] ++ (lib.optional stdenv.isDarwin [darwin.apple_sdk.frameworks.Security]);

  cargoBuildFlags = ["--workspace"];
  cargoTestFlags = ["--workspace"];

  checkFlags = [
    "--skip=test::can_get_lines_and_columns"
    "--skip=test::create"
  ];

  postInstall = ''
    cp -R {lua,plugin} $out
  '';

  meta = with lib; {
    description = "";
    homepage = "https://github.com/tjdevries/sg.nvim";
    license = licenses.unlicense;
  };
}
