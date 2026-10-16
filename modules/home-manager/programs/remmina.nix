{ lib, config, isLinux, pkgs, ... }:
let
  cfg = config.remmina;
in
{
  options.remmina.enable = lib.mkEnableOption "Remmina" // {
    default = isLinux;
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.remmina ]; };
}
