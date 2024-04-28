{ config, lib, ... }: {
  options = {
    nh.enable = lib.mkEnableOption "Nix Helper";
  };

  config = {
    programs.nh = {
      enable = config.nh.enable;
      flake = "/home/${config.username}/dotfiles";
      clean = {
        enable = true;
        extraArgs = "--keep-since 4d --keep 3";
      };
    };
  };
}
