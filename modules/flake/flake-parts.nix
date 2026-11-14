# The flake's frame: which systems get packages, apps and checks, and the
# outputs host files define.
{
  inputs,
  lib,
  moduleLocation,
  ...
}:
let
  inherit (lib) mkOption types;

  # Every aspect is published as a module keyed by its name, so importing it
  # from several aspects and hosts evaluates it once. This is flake-parts'
  # `flakeModules.modules` (extras/modules.nix) plus the `key` it leaves as a
  # TODO; without it a second import defines everything twice.
  publish =
    class: name: module:
    { ... }:
    {
      key = "flake.modules.${class}.${name}";
      _class = class;
      _file = "${toString moduleLocation}#modules.${class}.${name}";
      imports = [ module ];
    };
in
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];

  options.flake = {
    modules = mkOption {
      type = types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule);
      default = { };
      apply = lib.mapAttrs (class: lib.mapAttrs (publish class));
      description = ''
        Aspects by module class (`nixos`, `darwin`, `homeManager`) and name.
        Host files and other aspects import them as
        `self.modules.<class>.<name>`.
      '';
    };

    # nix-darwin has no flakeModule; declared so each host file can add its own.
    darwinConfigurations = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
    };
  };

  config.systems = import inputs.systems;
}
