{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.coreutils;
in
{
  options = {
    coreutils.enable = lib.mkEnableOption "coreutils" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.uutils-coreutils-noprefix ]; };
}
