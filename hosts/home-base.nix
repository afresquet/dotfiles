{
  lib,
  config,
  outputs,
  isDarwin,
  ...
}:
{
  # Every category without a graphical session. terminal and dev also hold
  # GUI apps (a terminal emulator, desktop clients), which only the desktop
  # layer (hosts/home.nix) adds.
  imports =
    with outputs.homeModules;
    [
      nix.default
      system.default
      cli.default
      ai.default
    ]
    ++ lib.attrValues (
      removeAttrs terminal [
        "default"
        "ghostty"
      ]
    )
    ++ lib.attrValues (
      removeAttrs dev [
        "default"
        "herdr-desktop"
        "insomnia"
      ]
    );

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
