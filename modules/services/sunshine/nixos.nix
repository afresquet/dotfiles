{
  lib,
  config,
  ...
}:
let
  cfg = config.sunshine;
in
{
  options.sunshine = {
    enable = lib.mkEnableOption "Sunshine game-streaming host" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      # Don't launch with the graphical session; start it on demand instead.
      autoStart = false;
      openFirewall = true;
      # Required for DRM/KMS capture under Wayland (Hyprland).
      capSysAdmin = true;
    };
  };
}
