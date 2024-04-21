{ lib, config, ... }: {
  options = {
    zoxide.enable = lib.mkEnableOption "zoxide";
  };

  config = {
    zoxide.enable = lib.mkDefault true;

    programs.zoxide = {
      enable = config.zoxide.enable;

      enableBashIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableZshIntegration = true;

      options = [
        "--cmd cd"
      ];
    };
  };
}
