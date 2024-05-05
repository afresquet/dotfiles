{ lib, config, ... }:
let
  cfg = config.nushell;
in
{
  options = {
    nushell.enable = lib.mkEnableOption "nushell" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;

      extraConfig = ''
        $env.config = {
          show_banner: false,
        }
      '';

      shellAliases = config.home.shellAliases;
    };
  };
}
