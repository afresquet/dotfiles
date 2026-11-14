{
  flake.modules.nixos.network = _: {
    networking.networkmanager.enable = true;
  };
}
