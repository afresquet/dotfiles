{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.vlc;
in
{
  options = {
    vlc.enable = lib.mkEnableOption "VLC" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.vlc ]; };
}
