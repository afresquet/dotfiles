{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sddm;

  cursors = pkgs.catppuccin-cursors.mochaMauve;
in
{
  options = {
    sddm = {
      enable = lib.mkEnableOption "sddm" // {
        default = true;
      };

      # Extra KEY=VALUE pairs for the greeter process, e.g. a per-host
      # QT_SCALE_FACTOR. Merged into SDDM's single GreeterEnvironment string.
      greeterEnvironment = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable SDDM
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      # The Catppuccin theme is QML for Qt6.
      package = pkgs.kdePackages.sddm;
      theme = "catppuccin-mocha-mauve";
      settings = {
        # NixOS only sets a cursor for the default Breeze theme; without one
        # the greeter has no pointer at all.
        Theme = {
          CursorTheme = "catppuccin-mocha-mauve-cursors";
          CursorSize = 24;
        };
        # The SDDM daemon doesn't get the session's XCURSOR_PATH, so point the
        # greeter at the system icon dir explicitly.
        General.GreeterEnvironment = lib.concatStringsSep "," (
          [ "XCURSOR_PATH=/run/current-system/sw/share/icons" ] ++ cfg.greeterEnvironment
        );
      };
    };

    # Match the Stylix palette, font and wallpaper used in home-manager.
    environment.systemPackages = [
      (pkgs.catppuccin-sddm.override {
        flavor = "mocha";
        accent = "mauve";
        font = "Hack Nerd Font";
        background = ../../../assets/wallpaper.png;
        loginBackground = true;
      })
      cursors
    ];
  };
}
