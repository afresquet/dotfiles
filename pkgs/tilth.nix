{
  lib,
  rustPlatform,
  inputs,
  ...
}:
let
  src = inputs.tilth;
  cargoToml = lib.importTOML "${src}/Cargo.toml";
in
rustPlatform.buildRustPackage {
  pname = cargoToml.package.name;
  inherit (cargoToml.package) version;
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  doCheck = false;

  meta = {
    description = "Smart code reading for AI agents";
    homepage = "https://github.com/jahala/tilth";
    license = lib.licenses.mit;
    mainProgram = "tilth";
  };
}
