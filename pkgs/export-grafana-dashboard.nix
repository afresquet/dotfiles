{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "export-grafana-dashboard";
  runtimeInputs = with pkgs; [
    curl
    jq
  ];
  text = ''
    set -euo pipefail

    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
      cat >&2 <<EOF
    Usage: export-grafana-dashboard <uid> [output-file]

    Pulls the live JSON for a provisioned Grafana dashboard via the API,
    strips fields that change on every save (id, version, iteration), and
    writes the result for committing to the flake.

    Default output:
      \$HOME/dotfiles/modules/nixos/services/monitoring/dashboards/<uid>.json

    Env vars:
      GRAFANA_URL       (default: http://grafana.home-server)
      GRAFANA_USERNAME  (default: admin)
      GRAFANA_PASSWORD  (required; falls back to /run/agenix/grafana-password)
    EOF
      exit 64
    fi

    uid="$1"
    out="''${2:-$HOME/dotfiles/modules/nixos/services/monitoring/dashboards/$uid.json}"
    grafana_url="''${GRAFANA_URL:-http://grafana.home-server}"
    grafana_user="''${GRAFANA_USERNAME:-admin}"

    if [ -z "''${GRAFANA_PASSWORD:-}" ] && [ -r /run/agenix/grafana-password ]; then
      # tr -d '\n' guards against the user appending a trailing newline when
      # editing with `agenix -e`; basic auth would otherwise reject it.
      GRAFANA_PASSWORD=$(tr -d '\n' < /run/agenix/grafana-password)
    fi
    if [ -z "''${GRAFANA_PASSWORD:-}" ]; then
      echo "GRAFANA_PASSWORD not set (and /run/agenix/grafana-password not readable)" >&2
      exit 1
    fi

    mkdir -p "$(dirname "$out")"

    # `id` is auto-assigned per Grafana instance; `version` and `iteration`
    # change on every save and create noise diffs. Sort keys for stable diffs.
    if ! curl -sf -u "$grafana_user:$GRAFANA_PASSWORD" \
         "$grafana_url/api/dashboards/uid/$uid" \
       | jq -S '.dashboard | del(.id, .version, .iteration)' > "$out.tmp"; then
      echo "Failed to fetch dashboard $uid from $grafana_url" >&2
      rm -f "$out.tmp"
      exit 1
    fi

    mv "$out.tmp" "$out"
    echo "Wrote $out"
  '';
}
