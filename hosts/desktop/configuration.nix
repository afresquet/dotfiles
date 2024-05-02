# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ outputs, ... }:
{
  imports = [
    ../configuration.nix

    ./settings.nix

    ./hardware-configuration.nix

    outputs.nixosModules.gaming
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
}
