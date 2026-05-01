{
  lib,
  config,
  outputs,
  isDarwin,
  isLinux,
  ...
}:
{
  imports = [
    outputs.homeManagerModules.cli.default
    outputs.homeManagerModules.programs.default
    outputs.homeManagerModules.polyfills.default
    outputs.homeManagerModules.hyprland
    outputs.homeManagerModules.stylix
  ];

  gtk.gtk4.theme = null;

  home.username = config.username;
  home.homeDirectory = lib.mkDefault (
    if isDarwin then "/Users/${config.username}" else "/home/${config.username}"
  );

  git = {
    email = lib.mkDefault "29437693+afresquet@users.noreply.github.com";
    signingKey = lib.mkDefault "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
  };

  home.sessionVariables = {
    SHELL = lib.getExe config.shell;
    EDITOR = lib.getExe config.editor;
  }
  // lib.optionalAttrs isLinux {
    TERMINAL = lib.getExe config.terminal;
    BROWSER = lib.getExe config.browser;
  };

  home.shellAliases = {
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";
    c = "clear";
  };

  home.stateVersion = "23.11";

  programs.home-manager.enable = true;
}
