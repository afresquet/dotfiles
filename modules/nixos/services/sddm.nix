{ lib, config, ... }:
let
  cfg = config.sddm;
in
{
  options = {
    sddm.enable = lib.mkEnableOption "sddm" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable SDDM
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  };
}
