{
  flake.modules.nixos.mounting = _: {
    # Enable device mounting daemon
    services.devmon.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
  };
}
