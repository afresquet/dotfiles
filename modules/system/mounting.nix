{
  flake.modules.nixos.mounting = _: {
    config = {
      # Enable device mounting daemon
      services.devmon.enable = true;
      services.gvfs.enable = true;
      services.udisks2.enable = true;
    };
  };
}
