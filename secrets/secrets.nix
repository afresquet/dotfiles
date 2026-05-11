let
  keys = import ./keys.nix;

  allHostKeys = with keys; [
    alvaroDesktopHost
    alvaroLaptopHost
    alvarosMacMiniHost
    homeServerHost
  ];
in
{
  "tailscale-auth.age".publicKeys = [ keys.afresquet ] ++ allHostKeys;
}
