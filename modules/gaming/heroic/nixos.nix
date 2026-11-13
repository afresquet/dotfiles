{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.heroic;
in
{
  options = {
    heroic.enable = lib.mkEnableOption "Heroic Launcher" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.heroic ]; };
}
