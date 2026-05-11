{
  config,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    inputs.nixos-raspberrypi.nixosModules.sd-image

    outputs.nixosModules.polyfills.default
    outputs.nixosModules.services.ssh
    outputs.nixosModules.services.avahi
    outputs.nixosModules.services.tailscale
    outputs.nixosModules.services.pihole
    outputs.nixosModules.services.home-assistant
    outputs.nixosModules.services.caddy
    outputs.nixosModules.services.bluetooth

    ./settings.nix
  ];

  bluetooth.xboxController.enable = false;

  pihole.enable = true;
  home-assistant-container.enable = true;
  reverseProxy = {
    enable = true;
    dnsTarget = "100.85.40.30";
  };

  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  _module.args.nixos-raspberrypi = inputs.nixos-raspberrypi;

  nixpkgs.overlays = [
    outputs.overlays.additions
    outputs.overlays.modifications
  ];

  networking.hostName = config.hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Madrid";

  services.openssh.settings.PasswordAuthentication = false;

  users.users.${config.username} = {
    isNormalUser = true;
    initialPassword = "pi";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    inherit (config) description shell;
    openssh.authorizedKeys.keys = with keys; [
      afresquet
      alvaroDesktop
      alvaroLaptop
      alvarosMacMini
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
