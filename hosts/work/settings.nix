{ config, ... }:
{
  imports = [ ../settings.nix ];

  hostname = "mac-afresquet";
  username = "alvaro.fresquet";

  git = {
    email = "135608500+afresquet-ch@users.noreply.github.com";
    signingKey = "/Users/${config.username}/.ssh/id_ed25519.pub";
  };

  foot.enable = false;
  wl-clipboard.enable = false;
}
