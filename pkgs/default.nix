{
  pkgs,
  lib,
  utils,
  ...
}:
let
  packageFiles = utils.importDirWithNames ./.;
  mapPackageFiles =
    { name, path }:
    {
      ${name} = pkgs.callPackage path { };
    };
  packages = builtins.map mapPackageFiles packageFiles;
in
lib.mergeAttrsList packages
