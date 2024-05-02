{ pkgs, ... }:
{
  imports = [ ../settings.nix ];

  hostname = "Alvaro-Laptop";
  username = "afresquet";
  description = "Alvaro";
  shell = pkgs.nushell;
}
