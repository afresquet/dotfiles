{
  flake.modules.homeManager.pay-respects =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      pr = config.programs.pay-respects;
    in
    {
      config = {
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
    };
}
