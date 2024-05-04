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

      environmentVariables = {
        EDITOR = config.editor.path;
      };

      extraConfig = ''
        $env.config = {
          show_banner: false,
        }

        # run fastfetch on launch
        ${config.terminal.onInit}
      '';

      shellAliases = config.home.shellAliases;
    };
  };
}
