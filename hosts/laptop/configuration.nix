# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, inputs, ... }:
let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../configuration.nix

    ./settings.nix

    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    ./hardware-configuration.nix
  ];

  services.libinput.touchpad.disableWhileTyping = true;
  openlogi.enable = true;

  # fprintd is enabled by nixos-hardware. SDDM authenticates through the
  # `login` stack, where pam_fprintd runs before pam_unix and blocks on the
  # sensor after a password is typed. Keep login password-only (the password
  # is also what unlocks gnome-keyring).
  security.pam.services.login.fprintAuth = false;
  # Hyprlock handles fingerprint natively alongside the password field, so
  # its PAM stack (defined in ../configuration.nix) must stay password-only too.
  security.pam.services.hyprlock.fprintAuth = false;

  # SDDM's Weston compositor runs at 1x, so the greeter is tiny on this panel.
  # Match the scale Hyprland picks for eDP-1 ("auto").
  sddm.greeterEnvironment = [ "QT_SCALE_FACTOR=1.5" ];

  users.users.${config.username}.openssh.authorizedKeys.keys = with keys; [
    afresquet
    alvaroDesktop
    alvarosMacMini
    alvaroPhone
  ];
}
