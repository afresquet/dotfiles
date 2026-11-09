{ pkgs, ... }:
{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  herdr-desktop.enable = true;

  stylix.opacity.terminal = 0.95;

  home.packages = with pkgs; [
    ruby
    cocoapods
  ];
}
