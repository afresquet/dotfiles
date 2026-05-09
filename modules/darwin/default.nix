{ lib, utils, ... }:
utils.importDirAsAttrSet {
  dir = ./.;
  args = {
    inherit lib utils;
  };
}
