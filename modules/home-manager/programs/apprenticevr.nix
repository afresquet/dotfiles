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
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.apprenticevr ]; };
}
