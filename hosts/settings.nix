{ lib, ... }:
{
  options = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "Host Name";
    };

    username = lib.mkOption {
      type = lib.types.str;
      description = "Username";
    };

    description = lib.mkOption {
      type = lib.types.str;
      description = "User Description";
    };

    shell = lib.mkOption {
      type = lib.types.package;
      description = "User Shell";
    };
  };
}
