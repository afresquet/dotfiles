{
  flake.modules.nixos.network = _: {
    config = {
      networking.networkmanager.enable = true;
    };
  };
}
