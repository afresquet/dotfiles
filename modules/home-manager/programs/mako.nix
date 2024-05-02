{ lib, config, ... }:
let
  cfg = config.mako;
in
{
  options = {
    mako.enable = lib.mkEnableOption "Mako" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.mako = {
      enable = true;
      borderRadius = 5;
      borderSize = 2;
      layer = "overlay";
    };
  };
}
