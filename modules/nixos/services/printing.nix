{ lib, config, ... }:
let
  cfg = config.printing;
in
{
  options = {
    printing.enable = lib.mkEnableOption "Printing" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable CUPS to print documents.
    services.printing.enable = true;
  };
}
