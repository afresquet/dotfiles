final: prev:
let
  version = "0.24.0";
  src = prev.fetchFromGitHub {
    owner = "modem-dev";
    repo = "hunk";
    tag = "v${version}";
    hash = "sha256-Nb6OB7gD1+vyLbzB3Izjf3nPVcB8Yq1Y6UDhgC1ZyDg=";
  };
in
{
  # Remove once NixOS/nixpkgs#577760 lands
  hunk =
    if prev.lib.versionOlder prev.hunk.version version then
      prev.hunk.overrideAttrs (
        old:
        let
          node_modules = old.passthru.node_modules.overrideAttrs {
            inherit version src;
            outputHash = "sha256-Y0X1FlNcW7n55MSB8mO0BpOLH5Ju4n14ibex9KM9em8=";
          };
        in
        {
          inherit version src;
          # node_modules is a let binding upstream, interpolated by store path.
          configurePhase =
            builtins.replaceStrings [ "${old.passthru.node_modules}" ] [ "${node_modules}" ]
              old.configurePhase;
          passthru = old.passthru // {
            inherit node_modules;
          };
        }
      )
    else
      throw "hunk overlay: nixpkgs now ships ${prev.hunk.version} (>= ${version}); remove this overlay";
}
