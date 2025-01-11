{ config, ... }:
{
  imports = [ ../settings.nix ];

  hostname = "Alvaros-Mac-mini";

  git = {
    email = "29437693+afresquet@users.noreply.github.com";
    signingKey = "/Users/${config.username}/.ssh/id_ed25519.pub";
  };

  foot.enable = false;
  wl-clipboard.enable = false;
}
