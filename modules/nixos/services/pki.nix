{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.pki;
in
{
  options = {
    pki.distrustEmudhra = lib.mkEnableOption "distrusting the roots behind the compromised eMudhra intermediates" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.distrustEmudhra {
    # eMudhra intermediates with recoverable private keys chain to these two
    # roots (https://emudhra.we-have-a-problem.com, Oct 2026). Browsers block
    # them via CRLSets/OneCRL, but curl, Go, Python, etc. use the system
    # bundle and don't check revocation. Drop once nixpkgs' cacert is at
    # NSS >= 3.131.1. Verify: `curl https://dv-g3b-emudhra.we-have-a-problem.com`
    # must fail with a certificate error.
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
      "emSign ECC Root CA - G3"
    ];

    # Fail the build once nixpkgs ships the fixed bundle, so this workaround
    # gets removed instead of lingering (it also distrusts legitimate certs).
    assertions = [
      {
        assertion = !lib.versionAtLeast pkgs.cacert.version "3.131.1";
        message = ''
          cacert ${pkgs.cacert.version} includes the eMudhra distrust (NSS >= 3.131.1).
          Remove modules/nixos/services/pki.nix and its import in hosts/home-server/configuration.nix.
        '';
      }
    ];
  };
}
