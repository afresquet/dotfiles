{ lib, config, isLinux, pkgs, ... }:
let
  cfg = config.telegram-desktop;
in
{
  options.telegram-desktop.enable = lib.mkEnableOption "Telegram Desktop" // {
    default = isLinux;
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.telegram-desktop ]; };
}
