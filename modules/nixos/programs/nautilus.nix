{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.nautilus;
in
{
  options = {
    nautilus.enable = lib.mkEnableOption "Nautilus";
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.gnome.nautilus ]; };
}
