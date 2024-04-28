{ name, package ? name, bin ? name, extraArgs ? [ ], pkgs, lib }:
let
  extra = lib.foldr
    (cur: acc: ''
      --add-flags ${cur} \
      ${acc}
    '') ""
    extraArgs;
in
pkgs.symlinkJoin {
  inherit name;
  paths = [ pkgs.${package} ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/${bin} \
      --add-flags "--enable-features=UseOzonePlatform" \
      --add-flags "--ozone-platform=wayland" \
      ${extra}
  '';
}
