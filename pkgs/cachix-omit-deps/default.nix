# cachix with `push --omit-deps`, which pushes only the paths it is given and
# not their closure. Every upstream push command (push, daemon push,
# watch-store) computes the closure first and only leaves out what the target
# cache or cache.nixos.org already has; .github/scripts/cachix-push.sh needs
# to also leave out what the flake's other substituters serve.
{ lib, pkgs, ... }:
let
  inherit (pkgs.haskellPackages) cachix;
in
if cachix.version != "1.15.0" then
  throw "cachix is ${cachix.version}: rebase pkgs/cachix-omit-deps/omit-deps.patch onto it, or drop the package if upstream has learnt to push without dependencies"
else
  lib.getBin (pkgs.haskell.lib.compose.appendPatch ./omit-deps.patch cachix)
