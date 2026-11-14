# Machines with a screen. `nixos.desktop` is the shared system of the NixOS
# desktops (desktop, laptop); `homeManager.desktop` the GUI layer every
# graphical home gets (Macs included); `homeManager.linux-desktop` the
# Hyprland session on top of it.
{ inputs, self, ... }:
{
  flake.modules.nixos.desktop =
    { config, pkgs, ... }:
    {
      imports = with self.modules.nixos; [
        base
        nh
        heroic
        minecraft
        piper
        steam
        vr
        self.modules.nixos."1password"
        calibre
        discord
        docker
        dropbox
        microcontrollers
        obsidian
        rpi-imager
        slicers
        vlc
        vscode
        audio
        bootloader
        fonts
        fwupd
        keyring
        locale
        mounting
        mullvad
        network
        printing
        sddm
      ];

      # A desktop is used during the day: stage the upgrade for the next boot
      # and say when it ran.
      autoUpgrade = {
        operation = "boot";
        notify = true;
      };

      programs.hyprland = {
        enable = true;
        # set the flake package
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # make sure to also set the portal package, so that they are in sync
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        xwayland.enable = true;
      };

      # PAM service for the home-manager hyprlock module.
      security.pam.services.hyprlock = { };

      # Power button: a short press suspends; holding it for ~5s does a clean
      # poweroff (logind's default long-press action is "ignore", so without this
      # the only hold behaviour is the firmware's hard cut after ~10s).
      services.logind.settings.Login = {
        HandlePowerKey = "suspend";
        HandlePowerKeyLongPress = "poweroff";
      };

      users.users.${config.system.primaryUser} = {
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "tty"
          "dialout"
          "uinput"
        ];
        shell = pkgs.nushell;
      };

      # Release the stateful defaults were taken from at first install; leave it.
      system.stateVersion = "23.11";

      boot.kernelPackages = pkgs.linuxPackages_latest;

      # Electron/Chromium apps (Discord, Obsidian, VS Code, ...) run natively on
      # Wayland instead of through XWayland: nixpkgs' wrappers add the ozone flags
      # when this is set. A session variable so every login gets it via PAM.
      environment.sessionVariables.NIXOS_OZONE_WL = "1";

      nix = {
        settings = {
          auto-optimise-store = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
            "https://hyprland.cachix.org"
            "https://devenv.cachix.org"
            "https://nixos-raspberrypi.cachix.org"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          ];
        };
      };
    };

  flake.modules.homeManager.desktop =
    { lib, ... }:
    {
      key = "self.modules.homeManager.desktop";

      imports = with self.modules.homeManager; [
        base
        alacritty
        kitty
        insomnia
        stylix
      ];

      gtk.gtk4.theme = lib.mkForce null;
    };

  flake.modules.homeManager.linux-desktop =
    { lib, config, ... }:
    {
      imports = with self.modules.homeManager; [
        desktop
        wl-clipboard
        foot
        anki
        cliphist
        firefoxpwa
        ghostty
        obs-studio
        remmina
        rofi
        swaync
        swayosd
        telegram-desktop
        waybar
        wlogout
        zen-browser
        hyprland
        auto-upgrade
      ];

      # upgrade-notify's desktop notifications are notify-send.
      autoUpgrade.notify = true;

      home.sessionVariables = {
        TERMINAL = lib.getExe config.programs.ghostty.package;
        BROWSER = lib.getExe config.programs.zen-browser.finalPackage;
      };
    };
}
