{ utils, ... }:
let
  cliModules = utils.importDirAsAttrSet { dir = ./.; };
  defaultModule = {
    default = {
      imports = utils.importDir ./.;
    };
  };
in
cliModules // defaultModule
