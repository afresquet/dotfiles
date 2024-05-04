{ lib, pkgs, ... }:
{
  options =
    with lib;
    let
      package = {
        package = mkOption { type = types.package; };
        path = mkOption { type = types.str; };
      };
    in
    {
      hostname = mkOption { type = types.str; };
      username = mkOption { type = types.str; };
      description = mkOption { type = types.str; };
      shell = package;
      terminal = rec {
        package = mkOption { type = types.package; };
        path = mkOption { type = types.str; };
        onInit = mkOption {
          type = types.str;
          default = "";
        };
        run = mkOption { type = types.functionTo types.str; };
      };
      editor = package;
      browser = package;
      fileManager = package;
      monitors = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              name = mkOption { type = types.str; };
              width = mkOption { type = types.int; };
              height = mkOption { type = types.int; };
              refreshRate = mkOption { type = types.float; };
              x = mkOption { type = types.int; };
              y = mkOption { type = types.int; };
              scale = mkOption { default = "auto"; };
              enable = mkOption { type = types.bool; };
            };
          }
        );
      };
    };

  config =
    let
      packageBin = name: binary: rec {
        package = pkgs.${name};
        path = "${package}/bin/${binary}";
      };
      package = name: packageBin name name;

      terminalPackage = package "foot";
    in
    {
      username = "afresquet";
      description = "Alvaro";
      shell = packageBin "nushell" "nu";
      terminal = terminalPackage // {
        run = program: "${terminalPackage.path} ${program}";
      };
      editor = packageBin "helix" "hx";
      browser = package "brave";
      fileManager = rec {
        package = pkgs.gnome.nautilus;
        path = "${package}/bin/nautilus";
      };
    };
}
