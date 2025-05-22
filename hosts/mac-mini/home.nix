{
  lib,
  config,
  inputs,
  outputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.stylix.homeModules.stylix

    outputs.homeManagerModules.cli.default

    ./settings.nix
  ];

  home.activation = {
    rsync-home-manager-applications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rsyncArgs="--archive --checksum --chmod=-w --copy-unsafe-links --delete"
      apps_source="$genProfilePath/home-path/Applications"
      moniker="Home Manager Trampolines"
      app_target_base="${config.home.homeDirectory}/Applications"
      app_target="$app_target_base/$moniker"
      mkdir -p "$app_target"
      ${pkgs.rsync}/bin/rsync $rsyncArgs "$apps_source/" "$app_target"
    '';
  };

  stylix = {
    image = /home/${config.username}/dotfiles/assets/wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";
    fonts.monospace = {
      name = "Hack Nerd Font Mono";
      package = pkgs.nerdfonts;
    };
    opacity.terminal = 0.95;
    targets = {
      helix.enable = false;
    };
  };

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = config.username;
  home.homeDirectory = "/Users/${config.username}";

  home.sessionVariables = {
    SHELL = lib.getExe config.shell;
    EDITOR = lib.getExe config.editor;
  };

  home.shellAliases = {
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";
    c = "clear";
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
