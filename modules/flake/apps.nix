# `nix run .#update-claude-code [version]` refreshes the pinned claude-code
# manifest (overlays/claude-code) to upstream's latest release.
{
  perSystem =
    { pkgs, ... }:
    let
      script = pkgs.writeShellApplication {
        name = "update-claude-code";
        runtimeInputs = with pkgs; [
          curl
          git
          jq
        ];
        text = ''
          base="https://downloads.claude.ai/claude-code-releases"
          target="$(git rev-parse --show-toplevel)/overlays/claude-code/manifest.json"
          current=$(jq -r .version "$target")
          version="''${1:-$(curl -fsSL "$base/latest")}"
          if [ "$version" = "$current" ]; then
            echo "claude-code is already at $current"
            exit 0
          fi
          tmp=$(mktemp)
          trap 'rm -f "$tmp"' EXIT
          curl -fsSL "$base/$version/manifest.zst.json" -o "$tmp"
          jq -e .platforms "$tmp" >/dev/null
          mv "$tmp" "$target"
          echo "claude-code: $current -> $version"
        '';
      };
    in
    {
      apps.update-claude-code = {
        type = "app";
        program = pkgs.lib.getExe script;
        meta.description = "Update the pinned claude-code release manifest";
      };
    };
}
