# nix-direnv 3.2.0 touches `flake-profile-*` on every cached load, which also
# bumps the watched `flake-profile-<hash>.rc` and makes every other shell in
# the repo reload (nix-community/nix-direnv#786). Only touch the 40-char-hash
# GC root symlink.
# Fixed upstream by #790, which deletes the touch line entirely, so the build
# fails with a reminder once a nixpkgs release no longer contains it.
# Patched in preFixup because the resholve wrapper copies $src to $out
# verbatim, so postPatch never reaches the installed file.
final: prev: {
  nix-direnv = prev.nix-direnv.overrideAttrs (old: {
    preFixup = ''
      direnvrc=$out/share/nix-direnv/direnvrc
      if ! grep -qF '"''${layout_dir}"/flake-profile-* ' "$direnvrc"; then
        echo "nix-direnv no longer touches flake-profile-*: nix-community/nix-direnv#790 is released, drop overlays/nix-direnv-gcroots-touch.nix" >&2
        exit 1
      fi
      chmod u+w "$direnvrc"
      substituteInPlace "$direnvrc" --replace-fail \
        '"''${layout_dir}"/flake-profile-* ' \
        '"''${layout_dir}"/flake-profile-???????????????????????????????????????? '
    ''
    + old.preFixup;
  });
}
