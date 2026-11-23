# GitHub agent

A GitHub App (bot `valaxor[bot]`) that works on issues and PRs labelled
`agent` in every repo it's installed on. It runs on the Mac mini:
`github_agent.py` is the dispatcher, a launchd daemon running as the `agent`
user, and `github-agent.nix` is the module that configures it. This file
covers setting it up, using it, what a repo can expect from it, and running
it.

## How it works

1. A webhook delivery reaches the Mac through Tailscale Funnel
   (`https://alvaros-mac-mini.<tailnet>:8443/github-webhook`). The dispatcher
   checks its signature and queues the issue or PR.
2. A job reads the whole thread (comments, reviews, inline comments, and the
   agent's own PR for an issue), keeping only comments from people with write
   access and from `trustedBots`, and writes it to a context file. For an
   issue, it adds the issue's labels, milestone, parent, sub-issues and
   blockers, and numbers its checklist. While a blocker is open, it waits.
3. The **coordinator**, a read-only Claude Code session (`coordinator.md`),
   decides whether to `ask`, `implement` or `skip`.
4. For an issue, the plan is posted, and the agent waits until you add
   `agent:plan-approved`. Follow-ups on its PR, and PRs you label yourself,
   don't wait.
5. The **implementer** (`implementer.md`) makes the change on the branch
   `agent/issue-<n>`, or on the PR's own branch, and commits it.
6. The dispatcher pushes, opens or updates the PR, keeps the issue's
   checklist, and requests your review.

It comments only when it needs you: a plan to approve, a question, a
blocker or a failure. Everything else, a skip included, is silent, and the
code answers review comments. In an inline thread it replies only to a
question.

Only the dispatcher holds GitHub credentials. The two agents can't reach
GitHub.

## Using it

- **Start:** add `agent` to an issue or PR. Removing the label and adding it
  again forces a fresh run.
- **Answering questions:** the agent adds `agent:needs-info` while it waits.
  Answer in a comment, and it picks up from there.
- **Approving a plan:** add `agent:plan-approved` to the issue. That label
  stays on, so later rounds on the issue implement without stopping.
- **Feedback:** review its PR or comment on it, including inline comments.
  It answers an inline comment in its thread only if it asks a question.
- **Checklist:** in an issue body with `## Work` steps (`- [ ] …`), it ticks
  each step once a pushed commit of its branch completes it. It adds the
  decisions it takes to `## Decisions` as `- [x] <decision>: <why>.`, and
  strikes through the ones it replaces:
  `- [ ] ~~<decision>~~ Replaced by <what>: <why>.`. It never deletes an item
  and never appends shas; the merged PR links the commits. Ticking a box and
  the trailing `(abc1234)` of older ticks aren't news to it, whoever writes
  them. Any other edit to the body is.
- **Dependencies:** an issue blocked by an open issue waits, silently, and
  starts within the hour after the blocker closes.
- **Merging:** approve its PR. Once every Actions run on the approved commit
  has passed (waiting for them, including a build that waits on an
  environment approval, for up to a day), it squash-merges, using the PR
  title in the repo's commit style, and deletes the `agent/issue-<n>` branch.
  A failed run or a newer push after your approval blocks the merge.
- **Base branch:** a comment containing `<!-- agent-base: <branch> -->` makes
  the work start from that branch instead of the default one. The PR still
  goes into the default branch, carrying that branch's commits with the
  fix: for a failed flake update, merging it lands the update.
- **Main moves:** after every push to a branch, open labelled PRs that target
  it and no longer merge are rebased. The implementer resolves any conflicts.
- **CI failures:** links to failed Actions runs in the thread are fetched,
  and the last 300 lines of each failed job's log go into the context.
- **Stopping:** close the item or remove the label. Its worktree and run logs
  are deleted.

## Setting it up

### The GitHub App

Create it under your account's Developer settings, then install it on the
repos it should work on. Being installed on a repo is the only allowlist.

| Repository permission | Access | Used for |
|---|---|---|
| Contents | Read and write | Clone, push, merge, delete branches |
| Issues | Read and write | Read threads, comment, labels |
| Pull requests | Read and write | Open PRs, reviews, inline replies, review requests, merge |
| Actions | Read | Failed job logs |
| Workflows | Read and write | Only to let it change `.github/workflows/` |
| Metadata | Read | Required |

Without the Workflows permission, a change to `.github/workflows/` fails to
push with "refusing to allow a GitHub App to create or update workflow". Any
change the agent makes to a workflow file runs on its `agent/**` branch with
that repo's secrets, so keep this in mind before granting it.

- **Webhook URL:** the Funnel address above.
- **Webhook secret:** the contents of `secrets/github-webhook.age`.
- **Events:** Issues, Issue comment, Pull request, Pull request review, Pull
  request review comment, Push.

Set `githubAgent.appId` in the host to the App ID.

### Secrets

All three are agenix secrets owned by `agent`, mode 0400:

- `github-agent.age`: the App's private key (`.pem`).
- `github-webhook.age`: the webhook secret.
- `claude-agent-token.age`: a Claude Code OAuth token, from
  `claude setup-token`.

### Tailscale Funnel

The tailnet policy must grant `funnel` to the Mac mini, with HTTPS
certificates enabled. The `github-agent-funnel` daemon reapplies the Funnel
at boot.

### First deploy

Creating the `agent` user makes nix-darwin's `dscl` wait on a macOS privacy
(TCC) dialog. Approve it over Screen Sharing; it only appears when the user
is created or deleted.

## What a repo can expect

The agents follow the repo's AGENTS.md, CLAUDE.md and CONTRIBUTING.md. Rules
written for an assistant next to the owner are read for unattended use: the
issue counts as the request to commit, and commands it would hand over
(sudo, deploys, rebuilds) are listed in the PR body instead of run.

Both agents' shell commands run in Claude Code's sandbox (Seatbelt):

- **Writes:** only under the repos and `~/.cache`. These variables point
  there: `XDG_CACHE_HOME`, `CARGO_HOME`, `GOPATH`, `GOCACHE`,
  `npm_config_cache`.
- **Git hooks and config:** the clone's `.bare/config` and `.bare/hooks`
  are read-only, so a dev shell can't install git hooks. The agent's
  environment sets `GITHUB_AGENT=1` so the repo can skip that (for example
  with `builtins.getEnv` under `--no-pure-eval`). The dispatcher never runs
  repo hooks.
- **Network:** only to `allowedDomains` (GitHub, the npm, PyPI, crates.io
  and Go registries, cache.nixos.org, `*.cachix.org`). Add a repo's own
  hosts there.
- **Unix sockets:** the Nix daemon (so `nix build` and `nix develop` work;
  builds run outside the sandbox) and `~/.cache/sccache/server.sock`.
- **Hidden:** the secrets, your home directory and the Claude token.
- **Tools:** `PATH` has git, coreutils, ripgrep, jq, curl and Nix. Anything
  else comes from the repo's dev shell, or from `githubAgent.packages`.

Each Claude session has `timeoutMinutes` (60) to finish. A cold first build
of a large Rust repo has to fit in that.

## Running it

- **Watching a session:** `github-agent-watch [owner/repo#n]` follows the
  latest one live, or replays a finished one. Press q to quit.
- **Acting as the App yourself:** `valaxor <gh args>` runs gh as
  `valaxor[bot]` on the current repo (or `GH_REPO`), with a token that only
  covers issues on that repo (labels, milestones and sub-issues included; no
  code, PRs or workflows). It decrypts `github-agent.age` with your own age identity
  (`VALAXOR_IDENTITY`, default `~/.ssh/id_ed25519`).
- **Logs:** `/var/log/github-agent.{log,err}` and
  `/var/log/github-agent-funnel.log`.
- **Files:** clones live in `~agent/repos/<owner>/<repo>/`: `.bare`, `main`,
  and one `issue-<n>` / `pr-<n>` worktree per item. Each item's run logs
  (context, transcripts) live in `~agent/state/<owner>/<repo>/<n>/`.
- **Reconcile:** hourly and at startup, it queues every open labelled item,
  catching missed deliveries and downtime. It also deletes the worktrees and
  run logs of finished items. For repos the App no longer sees (deleted or
  uninstalled), it deletes their clone and logs once untouched for 24 hours.
- **Concurrency:** `githubAgent.concurrency` items at once (4 on the Mac
  mini). Each item runs its own coordinator and implementer, so that many
  Claude sessions can run in parallel. They all draw on the same Claude
  account's limits.
- **Memory:** on the Mac mini (16 GiB), the agents share memory with
  Determinate's Linux builder VM. The VM runs only during a Linux build and
  is set to 12 GiB. Four busy agents plus a Linux build is more than the Mac
  has, so it swaps.
