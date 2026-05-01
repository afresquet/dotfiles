{ lib, config, isLinux, ... }:
let
  cfg = config.mako;
in
{
  options = {
    mako.enable = lib.mkEnableOption "Mako" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable {
    services.mako = {
      enable = true;
      settings = {
        borderRadius = 5;
        borderSize = 2;
        layer = "overlay";
      };
    };
  };
}
