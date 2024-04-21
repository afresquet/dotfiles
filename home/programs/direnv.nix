{ lib, config, ... }: {
  options = {
    direnv.enable = lib.mkEnableOption "Direnv";
  };

  config = {
    programs.direnv = {
      enable = config.direnv.enable;
      nix-direnv.enable = config.direnv.enable;

      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
    };
  };
}
