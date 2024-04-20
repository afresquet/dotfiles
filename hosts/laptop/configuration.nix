{ ... }: {
  imports =
    [
      # Include the results of the hardware scan.
      # ./hardware-configuration.nix
    ];

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
}
