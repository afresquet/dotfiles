{ pkgs, ... }:
{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  stylix.opacity.terminal = 0.95;

  home.packages = with pkgs; [
    ruby
    cocoapods
  ];
}
