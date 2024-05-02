{
  lib,
  config,
  pkgs,
  ...
}:
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
        EDITOR = "${pkgs.helix}/bin/hx";
      };

      extraConfig = ''
        $env.config = {
          show_banner: false,
        }

        # run fastfetch on launch
        ${pkgs.fastfetch}/bin/fastfetch
      '';
    };
  };
}
