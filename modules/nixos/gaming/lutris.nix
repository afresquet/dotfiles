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
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.lutris ]; };
}
