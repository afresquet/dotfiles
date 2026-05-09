{
  pkgs,
  config,
  outputs,
  ...
}:
{
  imports = [
    outputs.darwinModules.programs.default
    outputs.darwinModules.services.default
  ];

  system.primaryUser = "afresquet";

  homebrew.enable = true;
  homebrew.casks = [ ];

  system.activationScripts.postActivation.text = ''
    sudo -H -u ${config.system.primaryUser} sh -c '
      apps_source="${config.system.build.applications}/Applications"
      moniker="Nix Trampolines"
      app_target_base="$HOME/Applications"
      app_target="$app_target_base/$moniker"
      mkdir -p "$app_target"
      ${pkgs.rsync}/bin/rsync --archive --checksum --chmod=-w --copy-unsafe-links --delete "$apps_source/" "$app_target"
    '
  '';

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [ ];

  # Determinate manages the Nix installation; let it own nix.conf.
  nix.enable = false;

  # Set Git commit hash for darwin-version.
  # system.configurationRevision = configurationRevision;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
