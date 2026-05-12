{ lib, pkgs, ... }:
{
  options = with lib; {
    hostname = mkOption { type = types.str; };
    username = mkOption { type = types.str; };
    description = mkOption { type = types.str; };
    shell = mkOption { type = types.package; };
    terminal = mkOption { type = types.package; };
    editor = mkOption { type = types.package; };
    browser = mkOption { type = types.package; };
    fileManager = mkOption { type = types.package; };
    wallpaper = mkOption {
      type = types.path;
      default = ../assets/wallpaper.png;
    };
    monitors = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption { type = types.str; };
            width = mkOption { type = types.int; };
            height = mkOption { type = types.int; };
            refreshRate = mkOption { type = types.float; };
            x = mkOption { type = types.int; };
            y = mkOption { type = types.int; };
            scale = mkOption { default = "auto"; };
            enable = mkOption { type = types.bool; };
          };
        }
      );
    };
    tailnet.domain = mkOption {
      type = types.str;
      description = ''
        Tailscale MagicDNS suffix. Find with
        `tailscale status --self --json | jq -r .MagicDNSSuffix`.
        Per-host IPs are not stored — anything that needs an address either
        uses an FQDN like "$\{shortname}.$\{tailnet.domain}" (resolved via
        MagicDNS) or discovers it at runtime via `tailscale ip -4`.
      '';
    };
  };

  config = {
    username = lib.mkDefault "afresquet";
    description = lib.mkDefault "Alvaro";
    shell = lib.mkDefault pkgs.nushell;
    terminal = lib.mkDefault pkgs.ghostty;
    editor = lib.mkDefault pkgs.helix;
    browser = lib.mkDefault pkgs.brave;
    fileManager = lib.mkDefault pkgs.nautilus;

    tailnet.domain = "tail606ad7.ts.net";
  };
}
