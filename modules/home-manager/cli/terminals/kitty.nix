{ lib, config, ... }:
let
  cfg = config.kitty;
in
{
  options = {
    kitty.enable = lib.mkEnableOption "kitty" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      settings = {
        confirm_os_window_close = 0;
      };
    };
  };
}
