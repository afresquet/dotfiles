{ lib, config, ... }:
let
  cfg = config.ghostty;
in
{
  options = {
    ghostty.enable = lib.mkEnableOption "ghostty" // {
      default = true;
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
