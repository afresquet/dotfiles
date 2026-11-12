{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "upgrade-pending";
  runtimeInputs = with pkgs; [
    coreutils
    curl
  ];
  text = ''
    # Usage: upgrade-pending <flake ref> <deployed lock hash file>
    #
    # Gate for the auto-upgrade timers: exits 0 when the published flake's
    # flake.lock differs from the one the deployed configuration was built
    # from, 1 when it matches or GitHub can't be reached, 255 on misuse. Those
    # are ExecCondition's semantics: 1 skips the unit without failing it, 255
    # fails it so a broken setup doesn't skip silently forever.
    #
    # The timers fire every few hours rather than once right after the
    # flake-update workflow, so a lock committed late (a slow run, or a rerun
    # after fixing a failure) still deploys the same day.
    if [ $# -ne 2 ]; then
      echo "usage: upgrade-pending <flake ref> <deployed lock hash file>" >&2
      exit 255
    fi
    flake=$1 deployed_file=$2

    # github:owner/repo[/ref]; raw.githubusercontent.com takes HEAD for the
    # default branch.
    if [[ ! $flake =~ ^github:([^/]+)/([^/?#]+)(/([^?#]+))?$ ]]; then
      echo "upgrade-pending: only github:owner/repo[/ref] flakes are supported, got $flake" >&2
      exit 255
    fi
    url="https://raw.githubusercontent.com/''${BASH_REMATCH[1]}/''${BASH_REMATCH[2]}/''${BASH_REMATCH[4]:-HEAD}/flake.lock"

    if ! published=$(curl -fsSL --retry 3 --max-time 60 "$url" | sha256sum | cut -d' ' -f1); then
      echo "upgrade-pending: couldn't fetch $url, trying again next time"
      exit 1
    fi

    # Missing on a configuration built before this gate existed: upgrade.
    deployed=$(cat "$deployed_file" 2>/dev/null || true)
    if [ "$published" = "$deployed" ]; then
      echo "upgrade-pending: flake.lock unchanged since the last upgrade"
      exit 1
    fi
    echo "upgrade-pending: flake.lock changed, upgrading"
  '';
}
