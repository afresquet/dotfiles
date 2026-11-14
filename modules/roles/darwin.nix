# What both Macs share: Determinate Nix and the flake's overlays. The rest of
# a Mac (Tailscale, auto-upgrade, agenix secrets) is the Mac mini's alone; the
# work MacBook only gets its home config, updated by hand.
{ inputs, self, ... }:
{
  flake.modules.darwin.base = {
    imports = [ inputs.determinate.darwinModules.default ];

    nixpkgs.overlays = [
      self.overlays.additions
      self.overlays.modifications
    ];

    # Determinate manages the Nix installation and owns nix.conf; our settings
    # go to /etc/nix/nix.custom.conf through its module.
    determinateNix = {
      enable = true;
      # Set for everyone because the user is not a trusted Nix user (that is
      # root in all but name), so a flake's own `nixConfig` caches are
      # ignored. Without it the harvest project's devenv shell gets compiled
      # from source.
      customSettings = {
        extra-substituters = [ "https://devenv.cachix.org" ];
        extra-trusted-public-keys = [
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        ];
      };
    };

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    system.stateVersion = 5;

    nixpkgs.hostPlatform = "aarch64-darwin";
  };
}
