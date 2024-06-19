{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.insomnia;
in
{
  options = {
    insomnia.enable = lib.mkEnableOption "insomnia" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.insomnia ]; };
}
