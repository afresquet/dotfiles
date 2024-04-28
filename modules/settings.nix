{ lib, ... }: {
  options = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Host Name";
    };
  };
}
