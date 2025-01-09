{ lib, pkgs, ... }:
{
  options = with lib; {
    hostname = mkOption { type = types.str; };
    username = mkOption { type = types.str; };
    description = mkOption { type = types.str; };
    shell = mkOption { type = types.package; };
    terminal = mkOption { type = types.package; };
    editor = mkOption { type = types.package; };
    browser = mkOption { type = types.package; };
    fileManager = mkOption { type = types.package; };
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

  config = {
    username = "afresquet";
    description = "Alvaro";
    shell = pkgs.nushell;
    terminal = pkgs.ghostty;
    editor = pkgs.helix;
    browser = pkgs.brave;
    fileManager = pkgs.nautilus;
  };
}
