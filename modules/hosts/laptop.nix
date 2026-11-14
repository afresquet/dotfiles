# Alvaro-Laptop: the NixOS Framework laptop and its home config.
{
  inputs,
  self,
  config,
  ...
}:
let
  inherit (config.meta) keys;
in
{
  flake.nixosConfigurations.Alvaro-Laptop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      {
        imports = with self.modules.nixos; [
          desktop
          openlogi
          inputs.nixos-hardware.nixosModules.framework-13-7040-amd
          ./_laptop/hardware-configuration.nix
        ];

        networking.hostName = "Alvaro-Laptop";
        system.primaryUser = "afresquet";
        users.users.afresquet.description = "Alvaro";

        services.libinput.touchpad.disableWhileTyping = true;

        # fprintd is enabled by nixos-hardware. SDDM authenticates through the
        # `login` stack, where pam_fprintd runs before pam_unix and blocks on the
        # sensor after a password is typed. Keep login password-only (the password
        # is also what unlocks gnome-keyring).
        security.pam.services.login.fprintAuth = false;
        # Hyprlock handles fingerprint natively alongside the password field, so
        # its PAM stack (defined in the desktop aspect) must stay password-only too.
        security.pam.services.hyprlock.fprintAuth = false;

        # SDDM's Weston compositor runs at 1x, so the greeter is tiny on this panel.
        # Match the scale Hyprland picks for eDP-1 ("auto").
        sddm.greeterEnvironment = [ "QT_SCALE_FACTOR=1.5" ];

        users.users.afresquet.openssh.authorizedKeys.keys = with keys; [
          afresquet
          alvaroDesktop
          alvarosMacMini
          alvaroPhone
          heeler
        ];
      }
    ];
  };

  flake.homeConfigurations."afresquet@Alvaro-Laptop" =
    inputs.home-manager.lib.homeManagerConfiguration
      {
        inherit (self.nixosConfigurations.Alvaro-Laptop) pkgs;
        modules = [
          {
            imports = with self.modules.homeManager; [
              linux-desktop
              herdr-desktop
              hyprlock
            ];

            home.username = "afresquet";
            nixosAllowedUnfree = self.nixosConfigurations.Alvaro-Laptop.config.allowedUnfree;
            autoUpgrade.configuration = "afresquet@Alvaro-Laptop";

            btop.rocmSupport = true;

            hyprlock.fingerprint = true;

            hyprland.monitors = [
              {
                name = "eDP-1";
                width = 2256;
                height = 1504;
                refreshRate = 59.93;
                x = 0;
                y = 0;
                scale = "auto";
                enable = true;
              }
            ];

            waybar = {
              laptop = true;
              statsIcon = "<span size='x-large'>󰌢</span>";
            };
          }
        ];
      };
}
