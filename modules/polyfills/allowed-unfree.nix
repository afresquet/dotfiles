# https://github.com/NixOS/nixpkgs/issues/55674
#
# Modules append the unfree package names they need to `allowedUnfree`
# instead of flipping `allowUnfree` globally. Standalone home-manager
# instantiates its own nixpkgs with its own `nixpkgs.config`, so a home
# config can't see the NixOS predicate; host files pass the host's list in
# as `nixosAllowedUnfree` so packages the system allows stay allowed.
let
  allowedUnfree =
    class:
    { lib, config, ... }:
    {
      key = "self.modules.${class}.allowed-unfree";

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
    };
in
{
  flake.modules.nixos.allowed-unfree = allowedUnfree "nixos";
  flake.modules.homeManager.allowed-unfree = allowedUnfree "homeManager";
}
