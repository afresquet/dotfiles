# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./../../modules
    ];

  hostname = "Alvaro-Desktop";

  # Programs
  _1password.enable = true;
  brave.enable = true;
  cli-tools.enable = true;
  discord.enable = true;
  docker.enable = true;
  dropbox.enable = true;
  file-manager.enable = true;
  heroic.enable = true;
  minecraft.enable = true;
  nh.enable = true;
  obsidian.enable = true;
  steam.enable = true;
  vlc.enable = true;

  # Services
  bluetooth.enable = true;
  internet.enable = true;
  mounting.enable = true;
  mullvad.enable = true;
  ssh.enable = true;

  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
}
