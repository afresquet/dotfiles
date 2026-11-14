{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.pay-respects;
  pr = config.programs.pay-respects;
in
{
  options = {
    pay-respects.enable = lib.mkEnableOption "pay-respects" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pay-respects = {
      enable = true;
      # home-manager runs `pay-respects nushell`, which sets _PR_SHELL=nushell,
      # and pay-respects then tries to re-run the failed command through a
      # `nushell` executable that doesn't exist. Generate it with `nu` instead.
      enableNushellIntegration = false;
    };

    programs.nushell.extraConfig = lib.mkIf config.programs.nushell.enable ''
      source ${
        pkgs.runCommand "pay-respects-nushell-config.nu" { } ''
          ${lib.getExe pr.package} nu ${lib.concatStringsSep " " pr.options} >> "$out"
        ''
      }
    '';
  };
}
