{ lib, ... }: {
  options = {
    hostname = lib.mkOption {
      default = "nixos";
      type = lib.types.str;
      description = "Host name";
    };
  };
}
