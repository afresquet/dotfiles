# Shared by every NixOS desktop host (desktop, laptop). The Pi has its own
# configuration since it is headless and runs a different nixpkgs.
{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}:
{
  imports = [
    outputs.nixosModules.polyfills.default
    outputs.nixosModules.programs.default
    outputs.nixosModules.services.default
    outputs.nixosModules.gaming.default
  ];

  nixpkgs.overlays = [
    outputs.overlays.additions
    outputs.overlays.modifications
  ];

  dotfilesDir = "${config.users.users.${config.username}.home}/dotfiles";

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

  users.users.${config.username} = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "tty"
      "dialout"
      "uinput"
    ];
    inherit (config) description shell;
  };

  # Release the stateful defaults were taken from at first install; leave it.
  system.stateVersion = "23.11";

  boot.kernelPackages = pkgs.linuxPackages_latest;

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
      ];
      trusted-substituters = [
        "https://devenv.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
  };
}
