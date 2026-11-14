{
  flake.modules.nixos.printing = _: {
    config = {
      # Enable CUPS to print documents.
      services.printing.enable = true;
    };
  };
}
