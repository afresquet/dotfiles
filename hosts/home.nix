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
    outputs.homeModules.programs.default
    outputs.homeModules.hyprland
    outputs.homeModules.stylix
  ];

  gtk.gtk4.theme = lib.mkForce null;

  home.sessionVariables = lib.optionalAttrs isLinux {
    TERMINAL = lib.getExe config.terminal;
    BROWSER = lib.getExe config.browser;
  };
}
