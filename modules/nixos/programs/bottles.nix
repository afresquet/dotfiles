{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.bottles;
in
{
  options = {
    bottles.enable = lib.mkEnableOption "Bottles" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.bottles ]; };
}
