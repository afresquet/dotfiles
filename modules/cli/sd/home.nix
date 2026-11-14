{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sd;
in
{
  options = {
    sd.enable = lib.mkEnableOption "sd" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.sd ]; };
}
