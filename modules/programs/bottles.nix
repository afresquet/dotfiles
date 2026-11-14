{
  flake.modules.nixos.bottles =
    {
      pkgs,
      ...
    }:
    {
      config = {
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
    };
}
