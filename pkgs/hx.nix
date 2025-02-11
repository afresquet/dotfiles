{
  pkgs,
  helix,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
  config = tomlFormat.generate "helix-config" helix.settings;
in
pkgs.symlinkJoin {
  name = "helix-wrapped";

  nativeBuildInputs = [ pkgs.makeWrapper ];

  paths = [ pkgs.helix ];

  postBuild = ''
    wrapProgram $out/bin/hx --add-flags "--config '${config}'"
  '';

  meta.mainProgram = "hx";
}
