{
  lib,
  config,
  outputs,
  ...
}:
{
  imports = [
    outputs.homeManagerModules.cli.default
    outputs.homeManagerModules.polyfills.default

    ./settings.nix
  ];

  home.username = config.username;
  home.homeDirectory = "/home/${config.username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  git = {
    email = "29437693+afresquet@users.noreply.github.com";
    signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
  };

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
}
