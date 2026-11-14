# Custom packages (pkgs/) as `packages.<system>` and the `additions` overlay;
# patches to nixpkgs packages (overlays/) as the `modifications` overlay.
{ lib, inputs, ... }:
let
  nixFiles =
    dir:
    lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (dir + "/${file}")) (
      lib.filterAttrs (file: kind: kind == "directory" || lib.hasSuffix ".nix" file) (
        builtins.readDir dir
      )
    );

  packagesFor =
    pkgs: lib.mapAttrs (_: path: pkgs.callPackage path { inherit inputs; }) (nixFiles ../../pkgs);
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = packagesFor pkgs;
    };

  flake.overlays = {
    additions = final: _prev: packagesFor final;

    modifications =
      final: prev:
      lib.mergeAttrsList (map (path: import path final prev) (lib.attrValues (nixFiles ../../overlays)));
  };
}
