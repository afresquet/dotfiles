# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, ... }:
let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../configuration.nix

    ./settings.nix

    ./hardware-configuration.nix
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];

  users.users.${config.username}.openssh.authorizedKeys.keys = with keys; [
    afresquet
    alvaroLaptop
    alvarosMacMini
  ];
}
