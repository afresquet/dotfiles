# https://github.com/NixOS/nixpkgs/issues/55674
{ lib, config, ... }:
{
  options = {
    allowedUnfree = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    nixosAllowedUnfree = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Unfree packages allowed by the parent NixOS config; home-manager uses this to inherit from NixOS.";
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate =
      p: builtins.elem (lib.getName p) (config.allowedUnfree ++ config.nixosAllowedUnfree);
  };
}
