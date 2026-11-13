{
  lib,
  config,
  pkgs,
  isLinux,
  ...
}:
let
  cfg = config.wl-clipboard;
in
{
  options = {
    wl-clipboard.enable = lib.mkEnableOption "wl-clipboard" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.wl-clipboard-rs ]; };
}
