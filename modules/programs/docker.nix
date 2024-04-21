{ lib, config, ... }: {
  options = {
    docker.enable = lib.mkEnableOption "Docker";
  };

  config = {
    virtualisation.docker.enable = config.docker.enable;

    users.extraGroups.docker.members = [ config.username ];
  };
}
