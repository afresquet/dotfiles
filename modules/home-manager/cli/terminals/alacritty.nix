{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.alacritty;
in
{
  options = {
    alacritty.enable = lib.mkEnableOption "Alacritty" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;

      settings.shell.program = "${pkgs.nushell}/bin/nu";
    };
  };
}
