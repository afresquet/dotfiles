{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.apprenticevr;
in
{
  options = {
    apprenticevr.enable = lib.mkEnableOption "apprenticevr" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.apprenticevr ]; };
}
