{
  pkgs,
  lib,
  utils,
  ...
}:
let
  packageFiles = utils.importDirWithNames ./.;
  helix-hm = import ../modules/home-manager/cli/helix.nix {
    inherit lib pkgs;
    config = {
      helix.enable = true;
    };
  };
  helix = helix-hm.config.content.programs.helix;
  mapPackageFiles =
    { name, path }:
    {
      ${name} = pkgs.callPackage path { inherit helix; };
    };
  packages = builtins.map mapPackageFiles packageFiles;
in
lib.mergeAttrsList packages
