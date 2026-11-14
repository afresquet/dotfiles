{
  flake.modules.nixos.printing = _: {
    # Enable CUPS to print documents.
    services.printing.enable = true;
  };
}
