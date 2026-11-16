# Versions pinned outside flake.lock, because their sources have no stable
# URL to lock: `nix run .#update-pins` brings them all up to date, and the
# Flake update workflow runs it before `nix flake update`.
# `nix run .#update-claude-code [version]` refreshes just the claude-code
# manifest (overlays/claude-code), optionally to a given release.
{
  perSystem =
    { pkgs, lib, ... }:
    let
      updateClaudeCode = pkgs.writeShellApplication {
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

      # Uses the caller's nix (not a pinned one) for evaluating the flake and
      # prefetching.
      updatePins = pkgs.writeShellApplication {
        name = "update-pins";
        runtimeInputs = with pkgs; [
          curl
          git
          jq
        ];
        text = ''
          root=$(git rev-parse --show-toplevel)
          tmp=$(mktemp)
          trap 'rm -f "$tmp"' EXIT

          prefetch() { nix store prefetch-file --json "$1" | jq -r .hash; }

          ${lib.getExe updateClaudeCode}

          # HACS: the release zip, which carries the built frontend the
          # repository doesn't.
          target="$root/modules/homelab/hacs.json"
          current=$(jq -r .version "$target")
          latest=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/hacs/integration/releases/latest)
          version=''${latest##*/}
          if [ "$version" = "$current" ]; then
            echo "hacs is already at $current"
          else
            hash=$(prefetch "https://github.com/hacs/integration/releases/download/$version/hacs.zip")
            jq -n --arg version "$version" --arg hash "$hash" '{ $version, $hash }' > "$tmp"
            mv "$tmp" "$target"
            echo "hacs: $current -> $version"
          fi

          # grafana.com dashboards: every id the Pi declares, at its latest
          # revision. Ids no longer declared are dropped.
          target="$root/modules/homelab/monitoring/dashboards/grafana-com.json"
          ids=$(nix eval --json "$root#nixosConfigurations.Home-Server.config.monitoring.dashboards" \
            --apply 'ds: map (d: d.id) (builtins.filter (d: d.json == null && d.id != null) (builtins.attrValues ds))' |
            jq -r '.[]')
          pins='{}'
          for id in $ids; do
            revision=$(curl -fsSL "https://grafana.com/api/dashboards/$id" | jq -e .revision)
            current=$(jq -r --arg id "$id" '.[$id].revision // "none"' "$target")
            if [ "$revision" = "$current" ]; then
              hash=$(jq -r --arg id "$id" '.[$id].hash' "$target")
            else
              hash=$(prefetch "https://grafana.com/api/dashboards/$id/revisions/$revision/download")
              echo "grafana.com dashboard $id: $current -> $revision"
            fi
            pins=$(jq --arg id "$id" --argjson revision "$revision" --arg hash "$hash" \
              '.[$id] = { $revision, $hash }' <<<"$pins")
          done
          jq -S . <<<"$pins" > "$tmp"
          mv "$tmp" "$target"
        '';
      };
    in
    {
      apps = {
        update-claude-code = {
          type = "app";
          program = lib.getExe updateClaudeCode;
          meta.description = "Update the pinned claude-code release manifest";
        };
        update-pins = {
          type = "app";
          program = lib.getExe updatePins;
          meta.description = "Update every version pinned outside flake.lock";
        };
      };
    };
}
