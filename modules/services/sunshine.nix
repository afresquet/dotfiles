{
  flake.modules.nixos.sunshine = _: {
    config = {
      services.sunshine = {
        enable = true;
        # Don't launch with the graphical session; start it on demand instead.
        autoStart = false;
        openFirewall = true;
        # Required for DRM/KMS capture under Wayland (Hyprland).
        capSysAdmin = true;
      };
    };
  };
}
