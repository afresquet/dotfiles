{ self, ... }:
{
  flake.modules.nixos.docker =
    { config, ... }:
    {
      imports = [ self.modules.nixos.primary-user ];

      virtualisation.docker.enable = true;

      users.extraGroups.docker.members = [ config.system.primaryUser ];
    };
}
