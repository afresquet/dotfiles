final: prev:
let
  version = "13.3.1";
  srcs = {
    aarch64-darwin = { ext = "dmg"; hash = "sha256-rW5iYPCDFi5h6Hm5nyfWm5NK482/aBfdsoSs2KQwJlA="; };
    x86_64-linux = { ext = "AppImage"; hash = "sha256-zKrbI9XAvi3euBeGXaGn+8NC2epm76m5RD+BCARBJdY="; };
  };
in
{
  # Remove once NixOS/nixpkgs#576416 lands
  insomnia =
    if prev.lib.versionOlder prev.insomnia.version version then
      prev.insomnia.override {
        fetchurl =
          _:
          let
            s = srcs.${prev.stdenv.hostPlatform.system};
          in
          prev.fetchurl {
            url = "https://github.com/Kong/insomnia/releases/download/core%40${version}/Insomnia.Core-${version}.${s.ext}";
            inherit (s) hash;
          };
      }
    else
      throw "insomnia overlay: nixpkgs now ships ${prev.insomnia.version} (>= ${version}); remove this overlay";
}
