{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.nh;
in
{
  options = {
    nh.enable = lib.mkEnableOption "nh" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.nh ]; };
}
