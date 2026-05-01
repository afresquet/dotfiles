{ lib, config, isLinux, ... }:
let
  cfg = config.ghostty;
in
{
  options = {
    ghostty.enable = lib.mkEnableOption "ghostty" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;

      settings = {
        window-decoration = false;
      };
    };
  };
}
