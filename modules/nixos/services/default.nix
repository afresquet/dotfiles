{ utils, ... }:
let
  serviceModules = utils.importDirAsAttrSet { dir = ./.; };
  defaultModule = {
    default = {
      imports = utils.importDir ./.;
    };
  };
in
serviceModules // defaultModule
