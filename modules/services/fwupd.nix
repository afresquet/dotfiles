{
  flake.modules.nixos.fwupd = _: {
    config = {
      # Firmware Update Manager
      services.fwupd.enable = true;
    };
  };
}
