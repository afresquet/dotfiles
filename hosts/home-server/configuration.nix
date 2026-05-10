{
  config,
  inputs,
  outputs,
  ...
}:
{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    inputs.nixos-raspberrypi.nixosModules.sd-image

    outputs.nixosModules.polyfills.default
    outputs.nixosModules.services.ssh
    outputs.nixosModules.services.avahi
    outputs.nixosModules.services.tailscale

    ./settings.nix
  ];

  _module.args.nixos-raspberrypi = inputs.nixos-raspberrypi;

  nixpkgs.overlays = [
    outputs.overlays.additions
    outputs.overlays.modifications
  ];

  networking.hostName = config.hostname;
  networking.networkmanager.enable = true;

  services.openssh.settings.PasswordAuthentication = false;

  users.users.${config.username} = {
    isNormalUser = true;
    initialPassword = "pi";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    inherit (config) description shell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHTRDzddRLTvDOW2xY2mRunvH0ues6UOKYhUAP3WY4l afresquet@nixos"
    ];
  };

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  system.stateVersion = "25.05";
}
