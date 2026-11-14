{
  flake.modules.nixos.fwupd = _: {
    # Firmware Update Manager
    services.fwupd.enable = true;
  };
}
