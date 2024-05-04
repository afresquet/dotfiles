{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.wl-clipboard;
in
{
  options = {
    wl-clipboard.enable = lib.mkEnableOption "wl-clipboard" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.wl-clipboard-rs ]; };
}
