{ lib, config, pkgs, ... }: {
  options = {
    _1password.enable = lib.mkEnableOption "1Password";
  };

  config = {
    _1password.enable = lib.mkDefault true;

    packages = lib.mkIf config._1password.enable [
      pkgs._1password-gui
    ];

    allowedUnfree = [
      "1password-gui"
      "1password"
    ];
  };
}
