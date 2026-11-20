# `nix flake check` evaluates nixosConfigurations itself but skips
# darwinConfigurations and homeConfigurations, which are not standard
# outputs. One check per configuration forces its derivation path: building
# a check only writes that path to a file, never the configuration, so every
# host (the Macs included) is evaluated from any system without a build.
{ lib, self, ... }:
let
  attrs = {
    nixos = c: c.config.system.build.toplevel;
    darwin = c: c.config.system.build.toplevel;
    home = c: c.activationPackage;
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks = lib.concatMapAttrs (
        kind: drv:
        lib.mapAttrs' (
          name: c:
          lib.nameValuePair "eval-${kind}-${name}" (
            pkgs.writeText (lib.strings.sanitizeDerivationName "eval-${kind}-${name}") (
              # The path, not a dependency: the check never builds the configuration.
              builtins.unsafeDiscardStringContext (drv c).drvPath
            )
          )
        ) self."${kind}Configurations"
      ) attrs;
    };
}
