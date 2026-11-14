{
  flake.modules.homeManager.dotfiles-sync =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.dotfiles-sync;

      syncScript = pkgs.writeShellApplication {
        name = "dotfiles-sync";
        runtimeInputs = with pkgs; [
          coreutils
          git
          openssh
        ];
        runtimeEnv = {
          GIT_TERMINAL_PROMPT = "0";
          GIT_SSH_COMMAND = "ssh -o BatchMode=yes";
        };
        text = ''
          dir=${lib.escapeShellArg "${config.home.homeDirectory}/dotfiles"}
          cd "$dir" 2>/dev/null || exit 0
          git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0

          for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
            if [ -e "$git_dir/$state" ]; then
              echo "skipped: a $state is in progress"
              exit 0
            fi
          done

          upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || {
            echo "skipped: current branch has no upstream"
            exit 0
          }
          remote=''${upstream%%/*}
          branch=''${upstream#*/}

          # Fetch public GitHub remotes over HTTPS so no SSH key or agent is needed.
          url=$(git remote get-url "$remote")
          case "$url" in
            git@github.com:*) url="https://github.com/''${url#git@github.com:}" ;;
            ssh://git@github.com/*) url="https://github.com/''${url#ssh://git@github.com/}" ;;
          esac

          if ! git fetch --quiet "$url" "+refs/heads/$branch:refs/remotes/$upstream"; then
            echo "skipped: fetch failed"
            exit 0
          fi

          behind=$(git rev-list --count 'HEAD..@{u}')
          ahead=$(git rev-list --count '@{u}..HEAD')
          if [ "$behind" -eq 0 ]; then
            exit 0
          fi

          if [ "$ahead" -eq 0 ]; then
            # Refuses, leaving everything untouched, if uncommitted changes would
            # be overwritten.
            if git merge --ff-only --quiet '@{u}'; then
              echo "fast-forwarded $behind commit(s) from $upstream"
            else
              echo "skipped: uncommitted changes conflict with $upstream"
            fi
            exit 0
          fi

          if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "skipped: diverged from $upstream with uncommitted changes"
            exit 0
          fi

          if git rebase --quiet '@{u}' >/dev/null 2>&1; then
            echo "rebased $ahead local commit(s) onto $upstream"
          else
            git rebase --abort 2>/dev/null || true
            echo "skipped: local commits conflict with $upstream"
          fi
        '';
      };
    in
    {
      options.dotfiles-sync = {
        interval = lib.mkOption {
          type = lib.types.ints.positive;
          default = 15;
          description = "Minutes between syncs.";
        };
      };

      config = lib.mkMerge [
        { home.packages = [ syncScript ]; }

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          systemd.user.services.dotfiles-sync = {
            Unit.Description = "Fetch and pull the dotfiles repo when it applies cleanly";
            Service = {
              Type = "oneshot";
              ExecStart = lib.getExe syncScript;
            };
          };
          systemd.user.timers.dotfiles-sync = {
            Unit.Description = "Sync the dotfiles repo every ${toString cfg.interval} minutes";
            Timer = {
              OnBootSec = "2min";
              OnUnitActiveSec = "${toString cfg.interval}min";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })

        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          launchd.agents.dotfiles-sync = {
            enable = true;
            config = {
              ProgramArguments = [ (lib.getExe syncScript) ];
              StartInterval = cfg.interval * 60;
              RunAtLoad = true;
              StandardOutPath = "${config.home.homeDirectory}/Library/Logs/dotfiles-sync.log";
              StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/dotfiles-sync.log";
            };
          };
        })
      ];
    };
}
