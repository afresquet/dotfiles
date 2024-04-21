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
  };
}
