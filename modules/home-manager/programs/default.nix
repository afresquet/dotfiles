{ utils, ... }:
let
  programModules = utils.importDirAsAttrSet { dir = ./.; };
  defaultModule = {
    default = {
      imports = utils.importDir ./.;
    };
  };
in
programModules // defaultModule
