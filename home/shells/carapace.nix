{ lib, config, ... }: {
  options = {
    carapace.enable = lib.mkEnableOption "Carapace";
  };

  config = {
    carapace.enable = lib.mkDefault true;

    programs.carapace = {
      enable = config.carapace.enable;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
    };
  };
}
