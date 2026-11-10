{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.anki;
in
{
  options = {
    anki.enable = lib.mkEnableOption "Anki" // {
      default = false;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        anki
      ];
    })

    (lib.mkIf (!cfg.enable) {
      assertions = [
        {
          assertion =
            pkgs.anki.version == "26.09.4" && !(lib.any (p: (p.pname or "") == "zstd") pkgs.anki.buildInputs);
          message = "anki build fix (NixOS/nixpkgs#584713) or a new version (${pkgs.anki.version}) reached nixpkgs: set anki.enable back to true in modules/nixos/programs/anki.nix and remove this assertion";
        }
      ];
    })
  ];
}
