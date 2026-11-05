{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.brave;
in
{
  options = {
    brave.enable = lib.mkEnableOption "Brave Browser" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.brave ]; };
}
