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

    # The person the machines belong to.
    user = {
      name = mkOption {
        type = types.str;
        default = "afresquet";
        description = ''
          Login name, the default `system.primaryUser` (NixOS, nix-darwin)
          and `home.username`. A host with another account (the Pi's `pi`,
          the work MacBook's) sets `system.primaryUser`, and its home config
          reads it from there.
        '';
      };

      description = mkOption {
        type = types.str;
        default = "Alvaro Fresquet";
        description = "Display name (GECOS) of the desktops' user, shown by SDDM.";
      };
    };

    repo = mkOption {
      type = types.str;
      default = "github:afresquet/dotfiles";
      description = "Flake reference of this repository on GitHub.";
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
