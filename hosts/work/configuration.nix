{ config, inputs, ... }:
{
  imports = [
    inputs.determinate.darwinModules.default
    ./settings.nix
  ];

  networking.hostName = config.hostname;
  system.primaryUser = config.username;

  determinateNix = {
    enable = true;
    customSettings = {
      cores = 2;
      max-jobs = 4;
      extra-substituters = [ "https://devenv.cachix.org" ];
      extra-trusted-public-keys = [
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];
    };
  };

  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
