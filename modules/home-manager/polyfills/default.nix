{ utils, ... }:
let
  polyfills = utils.importDirAsAttrSet { dir = ./.; };
  default = {
    default = {
      imports = utils.importDir ./.;
    };
  };
in
polyfills // default
