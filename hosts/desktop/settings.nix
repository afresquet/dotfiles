{ pkgs, ... }:
{
  imports = [ ../settings.nix ];

  hostname = "Alvaro-Desktop";
  username = "afresquet";
  description = "Alvaro";
  shell = pkgs.nushell;
}
