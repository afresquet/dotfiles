{ config, ... }:
let
  inherit (config.meta) keyboard;
in
{
  flake.modules.nixos.locale = {
    # Set your time zone.
    time.timeZone = "Europe/Madrid";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    # Configure keymap in X11
    services.xserver = {
      enable = true;
      xkb = {
        inherit (keyboard) layout variant options;
      };
    };
  };
}
