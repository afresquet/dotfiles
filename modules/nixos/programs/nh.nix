{ config, lib, ... }:
let
  cfg = config.nh;
in
{
  options = {
    nh.enable = lib.mkEnableOption "Nix Helper" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nh = {
      enable = true;
      flake = "/home/${config.username}/dotfiles";
      clean = {
        enable = true;
        extraArgs = "--keep-since 4d --keep 3";
      };
    };
  };
}
