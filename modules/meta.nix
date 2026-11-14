# Values every host and aspect shares, read from the flake-parts scope as
# `config.meta.<name>` (aspect files close over it).
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.meta = {
    tailnet = mkOption {
      type = types.str;
      default = "tail606ad7.ts.net";
      description = ''
        Tailscale MagicDNS suffix. Find with
        `tailscale status --self --json | jq -r .MagicDNSSuffix`. Per-host IPs
        are not stored: anything that needs an address uses an FQDN like
        "alvaros-mac-mini.<tailnet>" or discovers it at runtime with
        `tailscale ip -4`.
      '';
    };

    wallpaper = mkOption {
      type = types.path;
      default = ../assets/wallpaper.png;
    };

    keys = mkOption {
      type = types.attrsOf types.str;
      default = import ../secrets/keys.nix;
      description = "SSH public keys by machine or person (secrets/keys.nix).";
    };
  };
}
