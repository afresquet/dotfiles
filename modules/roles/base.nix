# What every machine of the user's runs. `nixos.base` is every NixOS host
# (desktops and the Pi); `homeManager.base` every home config, headless Pi
# included, so it holds terminal tooling only.
{ self, ... }:
{
  flake.modules.nixos.base = {
    imports = with self.modules.nixos; [
      allowed-unfree
      primary-user
      auto-upgrade
      avahi
      bluetooth
      ssh
      tailscale
    ];

    nixpkgs.overlays = [
      self.overlays.additions
      self.overlays.modifications
    ];
  };

  flake.modules.homeManager.base =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      key = "self.modules.homeManager.base";

      imports = with self.modules.homeManager; [
        agenix
        bat
        btop
        carapace
        claude
        codex
        copilot
        coreutils
        direnv
        fastfetch
        fd
        fzf
        gh
        git
        grex
        helix
        herdr
        hunk
        jq
        lazygit
        nh
        pay-respects
        ripgrep
        sd
        bash
        nushell
        zsh
        silicon
        skills
        tilth
        skim
        ssh
        starship
        tokei
        wget
        yazi
        zellij
        zip
        zoxide
        allowed-unfree
        dotfiles-sync
      ];

      home.homeDirectory = lib.mkDefault (
        if pkgs.stdenv.hostPlatform.isDarwin then
          "/Users/${config.home.username}"
        else
          "/home/${config.home.username}"
      );

      git = {
        email = lib.mkDefault "29437693+afresquet@users.noreply.github.com";
        signingKey = lib.mkDefault "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      };

      home.sessionVariables = {
        SHELL = lib.getExe config.programs.nushell.package;
        EDITOR = lib.getExe config.programs.helix.package;
      };

      home.shellAliases = {
        cp = "cp -i";
        mv = "mv -i";
        rm = "rm -i";
        c = "clear";
      };

      home.stateVersion = lib.mkDefault "23.11";

      programs.home-manager.enable = true;
    };
}
