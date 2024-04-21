{ config, lib, ... }: {
  # https://github.com/NixOS/nixpkgs/issues/55674

  options = {
    allowedUnfree = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = p: builtins.elem (lib.getName p) config.allowedUnfree;
  };
}
