# Pins claude-code to the release manifest in ./manifest.json instead of
# waiting for nixpkgs. Refresh it with `nix run .#update-claude-code`.
# Falls back to nixpkgs' package once that is newer, so it never downgrades.
_final: prev:
let
  manifest = prev.lib.importJSON ./manifest.json;
in
{
  claude-code =
    if prev.lib.versionOlder manifest.version prev.claude-code.version then
      prev.claude-code
    else
      prev.claude-code.override { inherit manifest; };
}
