{ lib, config, ... }:
let
  cfg = config.docker;
in
{
  options = {
    docker.enable = lib.mkEnableOption "Docker" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    users.extraGroups.docker.members = [ config.username ];
  };
}
