{ config, ... }:
let
  inherit (config) meta;
in
{
  # nix-darwin's `system.primaryUser` on NixOS too, so aspects shared by both
  # (and NixOS-only ones) name the user the same way.
  flake.modules.nixos.primary-user =
    { lib, ... }:
    {
      options.system.primaryUser = lib.mkOption {
        type = lib.types.str;
        default = meta.user.name;
        description = "The user the machine belongs to: owner of its secrets, its dotfiles checkout and its desktop session.";
      };
    };
}
