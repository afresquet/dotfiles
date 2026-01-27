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
    vr.enable = lib.mkEnableOption "VR" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.wivrn = {
      enable = true;
      openFirewall = true;
      defaultRuntime = true;
      autoStart = true;
    };

    environment.systemPackages = [ pkgs.bs-manager ];
  };
}
