{ lib, config, ... }: {
  options = {
    wezterm.enable = lib.mkEnableOption "Wezterm";
  };

  config = {
    programs.wezterm = {
      enable = config.wezterm.enable;

      extraConfig = builtins.readFile ./wezterm.lua;
    };
  };
}
