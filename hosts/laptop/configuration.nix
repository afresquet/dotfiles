# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./../../modules
    ];

  # Programs
  _1password.enable = true;
  brave.enable = true;
  cli-tools.enable = true;
  discord.enable = true;
  docker.enable = true;
  dropbox.enable = true;
  file-manager.enable = true;
  obsidian.enable = true;
  vlc.enable = true;

  # Services
  bluetooth.enable = true;
  hyprland.enable = true;
  internet.enable = true;
  mounting.enable = true;
  mullvad.enable = true;
  ssh.enable = true;

  # Firmware Update Manager
  services.fwupd.enable = true;
  # Downgrade fingerprint sensor
  # services.fwupd.package = (import
  #   (builtins.fetchTarball {
  #     url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
  #     sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
  #   })
  #   {
  #     inherit (pkgs) system;
  #   }).fwupd;

  # Fingerprint scanner
  services.fprintd.enable = true;

  # Power management
  powerManagement.enable = true;
}
