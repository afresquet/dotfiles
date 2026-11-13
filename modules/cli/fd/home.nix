{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.fd;
in
{
  options = {
    fd.enable = lib.mkEnableOption "fd" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.fd ]; };
}
