{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.herdr-desktop;

  herdrPkgs = inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.herdr-desktop.enable = lib.mkEnableOption "Herdr desktop app" // {
    default = false;
  };

  # Exposed so other modules (the Hyprland workspace bind) can lib.getExe it.
  options.herdr-desktop.package = lib.mkOption {
    type = lib.types.package;
    default = herdrPkgs.herdr-desktop.override { herdr-core = config.herdr.corePackage; };
    readOnly = true;
    internal = true;
  };

  # herdr-core comes from the cli herdr module.
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionOlder pkgs.herdr-desktop.version herdrPkgs.herdr-desktop.version;
        message = "nixpkgs now has herdr-desktop ${pkgs.herdr-desktop.version} (NixOS/nixpkgs#584646 merged): drop the nixpkgs-herdr input and use pkgs.herdr-desktop/herdr-core again.";
      }
    ];

    home.packages = [ cfg.package ];
  };
}
