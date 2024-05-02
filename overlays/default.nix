{ lib, utils, ... }:
{
  additions =
    final: prev:
    import ../packages {
      inherit (final) pkgs;
      inherit lib utils;
    };

  modifications =
    final: prev:
    let
      overlayPaths = utils.importDir ./.;
      mapOverlays = path: import path final prev;
      overlays = builtins.map mapOverlays overlayPaths;
    in
    lib.mergeAttrsList overlays;
}
