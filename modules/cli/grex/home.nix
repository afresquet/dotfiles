{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.grex;
in
{
  options = {
    grex.enable = lib.mkEnableOption "grex" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.grex ]; };
}
