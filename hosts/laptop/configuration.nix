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

  users.users.${config.username}.openssh.authorizedKeys.keys = with keys; [
    afresquet
    alvaroDesktop
    alvarosMacMini
  ];
}
