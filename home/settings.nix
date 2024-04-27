{ lib, args, ... }: {
  options = {
    username = lib.mkOption {
      default = args.username;
      type = lib.types.str;
      description = "Home Manager Username";
    };

    hyprland.enable = lib.mkOption {
      default = args.hyprland.enable;
      type = lib.types.bool;
      description = "Hyprland";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            example = "DP-1";
          };
          width = lib.mkOption {
            type = lib.types.int;
            example = 1920;
            default = 1920;
          };
          height = lib.mkOption {
            type = lib.types.int;
            example = 1080;
            default = 1080;
          };
          refreshRate = lib.mkOption {
            type = lib.types.float;
            example = 60;
            default = 60;
          };
          x = lib.mkOption {
            type = lib.types.int;
            example = 0;
            default = 0;
          };
          y = lib.mkOption {
            type = lib.types.int;
            example = 0;
            default = 0;
          };
          scale = lib.mkOption {
            example = 1;
            default = "auto";
          };
          enable = lib.mkOption {
            type = lib.types.bool;
            example = true;
          };
        };
      });
      default = [ ];
    };

    touchpad.enable = lib.mkEnableOption "Touchpad";
  };
}
