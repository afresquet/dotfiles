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
    inputs.stylix.homeManagerModules.stylix

    outputs.homeManagerModules.cli.default
    outputs.homeManagerModules.hyprland
    outputs.homeManagerModules.programs.default
  ];

  stylix = {
    image = /home/${config.username}/dotfiles/assets/wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";
    fonts.monospace = {
      name = "Hack Nerd Font Mono";
      package = pkgs.nerdfonts;
    };
    opacity.terminal = 0.85;
    targets = {
      helix.enable = false;
    };
  };

  git = {
    email = "29437693+afresquet@users.noreply.github.com";
    signingKey = "/home/${config.username}/.ssh/id_ed25519.pub";
  };

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = config.username;
  home.homeDirectory = "/home/${config.username}";

  home.sessionVariables = {
    TERM = lib.getExe config.terminal;
    SHELL = lib.getExe config.shell;
    EDITOR = lib.getExe config.editor;
    BROWSER = lib.getExe config.browser;
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
