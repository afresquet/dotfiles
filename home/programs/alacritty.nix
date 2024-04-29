{ lib, config, pkgs, ... }: {
  options = {
    alacritty.enable = lib.mkEnableOption "Alacritty";
  };

  config = {
    programs.alacritty = {
      enable = config.alacritty.enable;

      settings.shell.program = "${pkgs.nushell}/bin/nu";
    };
  };
}
