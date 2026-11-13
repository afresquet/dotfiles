{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.herdr;

  # This test expects a token from the future to match no process; in the
  # build sandbox it matches its own sleeper. nixpkgs doesn't skip it.
  flakySkip = "--skip=sweep::tests::a_process_older_than_its_token_is_never_read";
  herdr-core = pkgs.herdr-core.overrideAttrs (old: {
    checkFlags = old.checkFlags ++ [ flakySkip ];
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
    assertions = [
      {
        assertion = !lib.elem flakySkip pkgs.herdr-core.checkFlags;
        message = "herdr: nixpkgs' herdr-core now skips sweep::tests::a_process_older_than_its_token_is_never_read itself; drop the checkFlags override in modules/home-manager/cli/herdr.nix";
      }
    ];

    programs.herdr.enable = true;

    home.packages = [
      cfg.corePackage
      # Heeler's host helper runs over ssh and needs Node.js 20+ on PATH.
      pkgs.nodejs
    ];
  };
}
