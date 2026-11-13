{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lutris;
in
{
  options = {
    lutris.enable = lib.mkEnableOption "Lutris" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.lutris ]; };
}
