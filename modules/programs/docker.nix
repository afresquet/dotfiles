{ lib, config, ... }: {
  options = {
    docker.enable = lib.mkEnableOption "Docker";
  };

  config = {
    docker.enable = lib.mkDefault true;

    virtualisation.docker.enable = config.docker.enable;

    users.extraGroups.docker.members = [ config.username ];
  };
}
