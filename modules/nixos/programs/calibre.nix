{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.calibre;
in
{
  options = {
    calibre.enable = lib.mkEnableOption "Calibre" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.calibre ]; };
}
