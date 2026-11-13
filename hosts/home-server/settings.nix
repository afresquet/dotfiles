{
  imports = [ ../settings.nix ];

  hostname = "Home-Server";
  username = "pi";
  description = "Pi";
  desktop = false;
  agentTelegram.enable = true;
}
