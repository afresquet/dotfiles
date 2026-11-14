# The flake's frame: which systems get packages, apps and checks, and the
# outputs host files define. `flake.modules.<class>.<name>` (from flake-parts'
# modules flakeModule) is where every aspect publishes itself.
{ inputs, lib, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
  ];

  config.systems = import inputs.systems;

  # nix-darwin has no flakeModule; declared so each host file can add its own.
  options.flake.darwinConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };
}
