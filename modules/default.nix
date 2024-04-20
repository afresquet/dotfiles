# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, config, username, shell, ... }:

{
  imports = [
    ./hyprland.nix
    ./locale.nix
    ./programs
    ./services
    ./polyfills
  ];

  steam.enable = lib.mkDefault false;

  ssh.enable = lib.mkDefault true;
  mullvad.enable = lib.mkDefault true;
  bluetooth.enable = lib.mkDefault true;
  internet.enable = lib.mkDefault true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    homeMode = "755";
    isNormalUser = true;
    description = "Alvaro";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = [ ];
    inherit shell;
  };


  # Enable device mounting daemon
  services.devmon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.allowedUnfree;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://cache.nixos.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
      trusted-users = [
        "root"
        username
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
}
