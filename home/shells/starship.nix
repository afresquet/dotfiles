{ lib, config, ... }: {
  options = {
    starship.enable = lib.mkEnableOption "Starship";
  };

  config = {
    programs.starship = {
      enable = config.starship.enable;

      settings = {
        add_newline = true;
      };

      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;
    };
  };
}
