# The GitHub agent: a GitHub App that works on issues and PRs labelled
# `agent` in every repo it's installed on. Its webhook reaches this Mac through
# Tailscale Funnel; the dispatcher (github_agent.py) runs as the `agent` user,
# keeps the repos it works on under its own home, asks on the thread when the
# request isn't clear and opens a PR once it is. README.md is the runbook.
{ inputs, self, ... }:
let
  user = "agent";
  home = "/Users/${user}";
  stateDir = "${home}/state";
  # The dispatcher listens here on localhost; the Funnel forwards to it.
  port = 9871;
  funnelPort = 8443;
  funnelPath = "/github-webhook";
in
{
  flake.modules.darwin.github-agent =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.githubAgent;
      secrets = config.age.secrets;
      ca = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

      # What the agents' shell commands find. nix comes from Determinate's
      # profile, so it's the daemon's own version.
      tools =
        with pkgs;
        [
          bashInteractive
          coreutils
          curl
          diffutils
          fd
          findutils
          gawk
          git
          gnugrep
          gnused
          gnutar
          gzip
          jq
          ripgrep
        ]
        ++ cfg.packages;
      path = "${lib.makeBinPath tools}:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin";

      # Both agents' shell commands run in Claude Code's sandbox (Seatbelt on
      # macOS): writes only under the repos and caches, network only to
      # `allowedDomains`, and neither the secrets, your home nor the Claude
      # token visible. The `agent` user is the outer boundary.
      denied = [
        "/run/agenix"
        "/private/var/run/agenix.d"
        "/Users/${config.system.primaryUser}"
      ];
      settings =
        phase: autoAllowBash:
        pkgs.writeText "github-agent-${phase}.json" (
          builtins.toJSON {
            sandbox = {
              enabled = true;
              failIfUnavailable = true;
              autoAllowBashIfSandboxed = autoAllowBash;
              allowUnsandboxedCommands = false;
              network = {
                inherit (cfg) allowedDomains;
                # nix asks the daemon, which builds and fetches outside the
                # sandbox. Seatbelt matches the resolved path, and
                # /nix/var/nix/daemon-socket/socket links to the /var/run one.
                allowUnixSockets = [
                  "/nix/var/nix/daemon-socket/socket"
                  "/private/var/run/nix-daemon.socket"
                ];
              };
              filesystem = {
                allowWrite = [
                  cfg.reposDir
                  "${home}/.cache"
                ];
                denyRead = denied;
              };
              credentials.envVars = [
                {
                  name = "CLAUDE_CODE_OAUTH_TOKEN";
                  mode = "deny";
                }
              ];
            };
            # No "Generated with Claude Code" footer or Co-Authored-By trailer.
            attribution = {
              commit = "";
              pr = "";
            };
            # The Read and Edit tools aren't sandboxed; these keep them out too.
            permissions.deny = lib.concatMap (p: [
              "Read(/${p}/**)"
              "Edit(/${p}/**)"
            ]) denied;
          }
        );

      # The coordinator only reads; in print mode anything not allowed is
      # denied rather than asked.
      coordinatorArgs = [
        "--settings"
        "${settings "coordinator" false}"
        "--allowedTools"
        "Read"
        "Glob"
        "Grep"
        "WebFetch"
        "WebSearch"
        "Bash(git log*)"
        "Bash(git show*)"
        "Bash(git diff*)"
        "Bash(git status*)"
        "Bash(git blame*)"
        "Bash(git grep*)"
        "Bash(ls *)"
        "Bash(rg *)"
      ];
      # The implementer runs anything the sandbox allows.
      implementerArgs = [
        "--settings"
        "${settings "implementer" true}"
        "--permission-mode"
        "acceptEdits"
        "--allowedTools"
        "Read"
        "Edit"
        "Write"
        "Glob"
        "Grep"
        "WebFetch"
        "WebSearch"
        "TodoWrite"
        "Bash"
      ];

      configFile = pkgs.writeText "github-agent.json" (
        builtins.toJSON {
          inherit (cfg)
            appId
            label
            reposDir
            trustedBots
            model
            timeoutMinutes
            concurrency
            ;
          inherit
            home
            path
            stateDir
            port
            coordinatorArgs
            implementerArgs
            ;
          needsInfoLabel = "${cfg.label}:needs-info";
          keyFile = secrets.github-agent.path;
          webhookSecretFile = secrets.github-webhook.path;
          claudeTokenFile = secrets.claude-agent-token.path;
          caFile = ca;
          shell = lib.getExe pkgs.bashInteractive;
          git = lib.getExe pkgs.git;
          openssl = lib.getExe pkgs.openssl;
          claude = lib.getExe pkgs.claude-code;
          coordinatorPrompt = builtins.readFile ./coordinator.md;
          implementerPrompt = builtins.readFile ./implementer.md;
        }
      );

      dispatcher = pkgs.writers.writePython3Bin "github-agent" {
        flakeIgnore = [ "E501" ];
      } (builtins.readFile ./github_agent.py);

      # `github-agent-watch [owner/repo#n]`: follow an agent session live
      # (the latest one by default), or replay a finished one.
      watch = pkgs.writeShellApplication {
        name = "github-agent-watch";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          jq
        ];
        text = ''
          dir=${lib.escapeShellArg stateDir}
          if [ $# -gt 0 ]; then
            dir="$dir/''${1%%#*}/''${1##*#}"
          fi
          file=$(find "$dir" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null |
            sort -rn | head -n 1 | cut -d' ' -f2- || true)
          if [ -z "$file" ]; then
            echo "no transcript yet" >&2
            exit 1
          fi
          echo "following $file (q to quit)"
          # Job control puts the pipeline in its own process group, so q can
          # stop tail and jq together.
          set -m
          tail -n +1 -F "$file" | jq -rR --unbuffered '
            fromjson? |
            def short: tostring | gsub("\n"; " ") | .[0:200];
            if .type == "assistant" then
              .message.content[] |
              if .type == "text" then "💬 \(.text)"
              elif .type == "thinking" then "💭 \(.thinking)"
              elif .type == "tool_use" then
                "🔧 \(.name) \(.input | .command // .file_path // .pattern // .url // . | short)"
              else empty end
            elif .type == "user" then
              .message.content[]? | select(.type? == "tool_result") |
              "   ↳ \(.content | if type == "array" then map(.text? // "") | join(" ") else . end | short)"
            elif .type == "result" then
              "✅ \(.subtype) after \((.duration_ms // 0) / 60000 | floor) min, \(.num_turns // "?") turns"
            else empty end' &
          pipeline=$!
          trap 'kill -- -$pipeline 2>/dev/null' EXIT INT TERM
          if [ -t 0 ]; then
            while IFS= read -rsn1 key; do
              [ "$key" = q ] && break
            done
          else
            wait "$pipeline"
          fi
        '';
      };

      tailscale = lib.getExe config.services.tailscale.package;
    in
    {
      imports = [
        inputs.agenix.darwinModules.default
        self.modules.darwin.allowed-unfree
        self.modules.darwin.daemon-users
        self.modules.darwin.tailscale
      ];

      options.githubAgent = {
        appId = lib.mkOption {
          type = lib.types.ints.positive;
          description = ''
            ID of the GitHub App the agent acts as (on the app's settings page).
            Permissions and webhook events are in README.md.
          '';
        };

        label = lib.mkOption {
          type = lib.types.str;
          default = "agent";
          description = ''
            Issues and PRs with this label are worked on. The agent adds
            `<label>:needs-info` while it waits for an answer.
          '';
        };

        reposDir = lib.mkOption {
          type = lib.types.str;
          default = "${home}/repos";
          description = "Where the agent keeps its clones, as <owner>/<repo>/{.bare,main,issue-<n>,pr-<n>}.";
        };

        trustedBots = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # CI files failures as issues and comments on them.
          default = [ "github-actions[bot]" ];
          description = ''
            Accounts whose comments count besides people with write access to
            the repo (owners, members, collaborators). Anyone else's comments
            are never shown to the agent.
          '';
        };

        model = lib.mkOption {
          type = lib.types.str;
          default = "opus";
        };

        timeoutMinutes = lib.mkOption {
          type = lib.types.ints.positive;
          default = 60;
          description = "Per Claude session (coordinator, implementer).";
        };

        concurrency = lib.mkOption {
          type = lib.types.ints.positive;
          # The Linux builder VM already takes 12 of the 16 GiB.
          default = 1;
          description = "Issues and PRs worked on at once.";
        };

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Extra tools on the agents' PATH (most repos bring theirs through Nix).";
        };

        allowedDomains = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "github.com"
            "*.github.com"
            "*.githubusercontent.com"
            "registry.npmjs.org"
            "registry.yarnpkg.com"
            "pypi.org"
            "files.pythonhosted.org"
            "crates.io"
            "*.crates.io"
            "proxy.golang.org"
            "sum.golang.org"
            "cache.nixos.org"
            "*.cachix.org"
          ];
          description = "Where the agents' shell commands may connect (package registries, mostly).";
        };
      };

      config = {
        allowedUnfree = [ "claude-code" ];

        daemonUsers.${user} = {
          uid = 483;
          inherit home;
          dirs = [
            home
            cfg.reposDir
            stateDir
            "${home}/.cache"
          ];
          logs = [
            "/var/log/github-agent.log"
            "/var/log/github-agent.err"
          ];
        };

        age.secrets =
          lib.genAttrs
            [
              "github-agent"
              "github-webhook"
              "claude-agent-token"
            ]
            (name: {
              file = ../../../secrets/${name}.age;
              owner = user;
              mode = "0400";
            });

        environment.systemPackages = [ watch ];

        launchd.daemons.github-agent.serviceConfig = {
          Label = "com.github-agent";
          UserName = user;
          GroupName = user;
          # See the wait4path rationale on the prometheus daemon.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              /bin/wait4path "$0"
              exec "$0" "$@"
            ''
            (lib.getExe dispatcher)
            "${configFile}"
          ];
          EnvironmentVariables = {
            HOME = home;
            SSL_CERT_FILE = ca;
          };
          WorkingDirectory = home;
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 60;
          StandardOutPath = "/var/log/github-agent.log";
          StandardErrorPath = "/var/log/github-agent.err";
        };

        # GitHub can't reach the tailnet, so Funnel exposes the one path
        # publicly over HTTPS and proxies it to the dispatcher. The tailnet
        # policy must grant `funnel` to this node, with HTTPS certificates on.
        # tailscaled keeps the setting; this reapplies it at boot, once
        # tailscaled is logged in.
        launchd.daemons.github-agent-funnel.serviceConfig = {
          Label = "com.github-agent.funnel";
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              /bin/wait4path "$0"
              for _ in $(seq 60); do
                if "$0" status --peers=false >/dev/null 2>&1; then
                  exec "$0" funnel --bg --yes --https=${toString funnelPort} \
                    --set-path=${funnelPath} http://127.0.0.1:${toString port}
                fi
                sleep 5
              done
              exit 1
            ''
            tailscale
          ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          ThrottleInterval = 60;
          StandardOutPath = "/var/log/github-agent-funnel.log";
          StandardErrorPath = "/var/log/github-agent-funnel.log";
        };
      };
    };
}
