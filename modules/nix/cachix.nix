# This flake's own closures, pushed by the Build workflow from main and the
# flake-update run, so auto-upgrades and rebuilds download what CI already
# built instead of compiling it. `extra-` so a host's own `substituters` list
# (and cache.nixos.org) stays as it is. Home configs use the system daemon's
# caches, so they get it from here.
let
  substituter = "https://afresquet-dotfiles.cachix.org";
  key = "afresquet-dotfiles.cachix.org-1:14Rw96q4DN7l6kkvY3ducxkBwDQrQv8BlHg4XIxkC50=";
in
{
  flake.modules.nixos.cachix.nix.settings = {
    extra-substituters = [ substituter ];
    extra-trusted-public-keys = [ key ];
  };

  flake.modules.darwin.cachix.determinateNix.customSettings = {
    extra-substituters = [ substituter ];
    extra-trusted-public-keys = [ key ];
  };
}
