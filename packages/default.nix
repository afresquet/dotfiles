{
  pkgs,
  lib,
  utils,
  ...
}:
let
  packagePaths = utils.importDir ./.;
  mapPackages = path: import path { inherit pkgs; };
  packages = builtins.map mapPackages packagePaths;
in
lib.mergeAttrsList packages
