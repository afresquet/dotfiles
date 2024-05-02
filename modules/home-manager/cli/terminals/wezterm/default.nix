{ lib, config, ... }:
let
  cfg = config.wezterm;
in
{
  options = {
    wezterm.enable = lib.mkEnableOption "Wezterm" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.wezterm = {
      enable = true;

      extraConfig = builtins.readFile ./wezterm.lua;
    };
  };
}
