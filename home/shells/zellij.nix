{ lib, config, ... }: {
  options = {
    zellij.enable = lib.mkEnableOption "Zellij";
  };

  config = {
    programs.zellij = {
      enable = config.zellij.enable;

      settings = {
        theme = "catppuccin-mocha";
      };
    };
  };
}
