{ lib, config, ... }: {
  options = {
    carapace.enable = lib.mkEnableOption "Carapace";
  };

  config = {
    programs.carapace = {
      enable = config.carapace.enable;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
    };
  };
}
