{
  lib,
  config,
  outputs,
  isDarwin,
  ...
}:
{
  imports = [
    outputs.homeModules.cli.default
    outputs.homeModules.polyfills.default
    outputs.homeModules.services.default
  ];

  home.username = config.username;
  home.homeDirectory = lib.mkDefault (
    if isDarwin then "/Users/${config.username}" else "/home/${config.username}"
  );
  dotfilesDir = lib.mkDefault "${config.home.homeDirectory}/dotfiles";

  git = {
    email = lib.mkDefault "29437693+afresquet@users.noreply.github.com";
    signingKey = lib.mkDefault "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
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

  home.stateVersion = lib.mkDefault "23.11";

  programs.home-manager.enable = true;
}
