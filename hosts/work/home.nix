{ pkgs, ... }:
{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  herdr-desktop.enable = true;

  # Work machine: update it by hand, not on a timer.
  autoUpgrade.enable = false;

  stylix.opacity.terminal = 0.95;

  # Real copies rather than symlinks so Spotlight indexes the apps.
  targets.darwin.copyApps.enable = true;
  targets.darwin.linkApps.enable = false;

  home.packages = with pkgs; [
    ruby
    cocoapods
  ];
}
