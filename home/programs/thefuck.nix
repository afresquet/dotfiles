{ lib, config, ... }: {
  options = {
    thefuck.enable = lib.mkEnableOption "thefuck";

    # https://github.com/nix-community/home-manager/pull/5343
    programs.thefuck.enableNushellIntegration = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = ''
        Whether to enable Nushell integration.
      '';
    };
  };

  config = {
    programs.thefuck.enable = config.thefuck.enable;

    # https://github.com/nix-community/home-manager/pull/5343
    programs.nushell = lib.mkIf config.programs.thefuck.enableNushellIntegration {
      extraConfig = ''
        alias fuck = ${config.programs.thefuck.package}/bin/thefuck $"(history | last 1 | get command | get 0)"
      '';
    };
  };
}
