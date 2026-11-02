{
  lib,
  rustPlatform,
  inputs,
  ...
}:
let
  src = inputs.skills.grepika;
  cargoToml = lib.importTOML "${src}/Cargo.toml";
in
rustPlatform.buildRustPackage {
  pname = cargoToml.package.name;
  inherit (cargoToml.package) version;
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  doCheck = false;

  meta = {
    description = "Token-efficient MCP server for ranked code search";
    homepage = "https://github.com/adamthewilliam/grepika";
    license = lib.licenses.mit;
    mainProgram = "grepika";
  };
}
