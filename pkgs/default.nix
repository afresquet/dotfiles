{
  pkgs,
  lib,
  utils,
  inputs,
  ...
}:
let
  packageFiles = utils.importDirWithNames ./.;
  helix-hm = import ../modules/cli/helix/home.nix {
    inherit lib pkgs;
    config = {
      helix.enable = true;
    };
  };
  helix = helix-hm.config.content.programs.helix;
  mapPackageFiles =
    { name, path }:
    {
      ${name} = pkgs.callPackage path { inherit helix inputs; };
    };
  packages = builtins.map mapPackageFiles packageFiles;
in
lib.mergeAttrsList packages
