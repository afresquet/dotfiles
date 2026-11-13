{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.piper;
in
{
  options = {
    piper.enable = lib.mkEnableOption "Piper" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.ratbagd.enable = true;

    environment.systemPackages = [ pkgs.piper ];
  };
}
