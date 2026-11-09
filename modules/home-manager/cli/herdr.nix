{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.herdr;

  herdrPkgs = inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # This test expects a token from the future to match no process; in the
  # build sandbox it matches its own sleeper.
  herdr-core = herdrPkgs.herdr-core.overrideAttrs (old: {
    checkFlags = old.checkFlags ++ [
      "--skip=sweep::tests::a_process_older_than_its_token_is_never_read"
    ];
  });
in
{
  options.herdr.enable = lib.mkEnableOption "Herdr" // {
    default = true;
  };

  # Shared with the desktop app, which embeds herdr-core's path.
  options.herdr.corePackage = lib.mkOption {
    type = lib.types.package;
    default = herdr-core;
    readOnly = true;
    internal = true;
  };

  # herdr-core (`hc`) on every host, so the desktop app can add them as machines.
  config = lib.mkIf cfg.enable {
    programs.herdr.enable = true;

    home.packages = [
      cfg.corePackage
      # Heeler's host helper runs over ssh and needs Node.js 20+ on PATH.
      pkgs.nodejs
    ];
  };
}
