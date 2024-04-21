{ lib, config, ... }: {
  options = {
    printing.enable = lib.mkEnableOption "Printing";
  };

  config = {
    # Enable CUPS to print documents.
    services.printing.enable = config.printing.enable;
  };
}
