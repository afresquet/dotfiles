{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.tailscale;
in
{
  options = {
    tailscale.enable = lib.mkEnableOption "Tailscale" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale ];

    services.tailscale.enable = true;
  };
}
