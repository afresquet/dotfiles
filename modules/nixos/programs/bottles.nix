{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.bottles;
in
{
  options = {
    bottles.enable = lib.mkEnableOption "Bottles" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.bottles ];

    # https://github.com/NixOS/nixpkgs/issues/513245#issuecomment-4320293674
    nixpkgs.overlays = [
      (_: prev: {
        openldap = prev.openldap.overrideAttrs {
          doCheck = !prev.stdenv.hostPlatform.isi686;
        };
      })
    ];
  };
}
