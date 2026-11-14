# Desktop layer on top of home-base.nix: GUI programs, Hyprland and Stylix.
{
  lib,
  config,
  outputs,
  isLinux,
  ...
}:
{
  imports = [
    ./home-base.nix
    outputs.homeModules.desktop.default
    outputs.homeModules.apps.default
    outputs.homeModules.gaming.default
    # The GUI apps home-base.nix leaves out; the rest of these categories
    # is already imported there (same paths, so the module system dedups).
    outputs.homeModules.terminal.default
    outputs.homeModules.dev.default
  ];

  gtk.gtk4.theme = lib.mkForce null;

  home.sessionVariables = lib.optionalAttrs isLinux {
    TERMINAL = lib.getExe config.terminal;
    BROWSER = lib.getExe config.browser;
  };
}
