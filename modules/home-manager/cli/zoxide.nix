{ lib, config, ... }:
let
  cfg = config.zoxide;
in
{
  options = {
    zoxide.enable = lib.mkEnableOption "zoxide" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enable = true;

      options = [ "--cmd cd" ];
    };

    home.sessionVariables._ZO_DOCTOR = "0";
  };
}
