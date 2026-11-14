# A headless home server: the NixOS base plus the infrastructure its apps
# plug into. Pi-hole is the LAN's DNS, Caddy gives each app a
# `<name>.home-server` vhost, the dashboard a Homepage tile, and monitoring
# runs the exporters the Mac mini's Prometheus scrapes. Apps are the host's
# choice.
{ self, ... }:
{
  flake.modules.nixos.server = {
    imports = with self.modules.nixos; [
      base
      pihole
      caddy
      dashboard
      monitoring
    ];
  };
}
