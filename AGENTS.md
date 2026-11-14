# AGENTS.md

Guidance for AI agents working in this repository. It is a Nix flake that
configures five machines: two NixOS desktops, a Raspberry Pi home server, a
Mac mini and a work MacBook, both on nix-darwin. `README.md` has the
host table and layout overview; this file is about how to change things
without breaking them.

## Ground rules

- Never run `sudo`, `nixos-rebuild`, `darwin-rebuild`, `home-manager switch`
  or the `nh` aliases. Prepare the change, verify it evaluates, then hand the
  user the command to run. The same goes for anything over SSH to another
  host: give the command, don't run it.
- Never commit or push unless asked. Don't `git add` for real either; use
  `git add -N <file>` (intent-to-add) so Nix can see a new file during
  evaluation.
- Commands you hand to the user are for nushell: `out+err>` instead of
  `2>&1`, `$env.FOO` instead of `$FOO`.
- Don't run `nix flake update`. Pinned versions are load-bearing: several
  overlays and assertions are tied to exact package versions on purpose.
  `.github/workflows/flake-update.yml` updates the lock weekly (or on
  demand) and commits it only once `check.yml` and `build.yml` pass on it;
  failures open a "Flake update failed" issue. `check.yml` runs on every
  push and tracks evaluation warnings in an "Evaluation warnings" issue;
  `build.yml` also runs when a push changes `flake.lock` on main.
- Formatting and lint are enforced. Run `nix fmt` after editing Nix files;
  `nix flake check` must pass before you report done.

## Verifying a change

Evaluate, don't build. Every host can be evaluated from a Mac or a Linux box;
nothing needs the target hardware.

```sh
nix fmt
nix flake check
nix eval --raw .#nixosConfigurations.Alvaro-Desktop.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.Alvaro-Laptop.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.Home-Server.config.system.build.toplevel.drvPath
nix eval --raw .#darwinConfigurations.Alvaros-Mac-mini.config.system.build.toplevel.drvPath
nix eval --raw .#darwinConfigurations.mac-afresquet.config.system.build.toplevel.drvPath
nix eval --raw '.#homeConfigurations."afresquet@Alvaro-Desktop".activationPackage.drvPath'
nix eval --raw '.#homeConfigurations."afresquet@Alvaro-Laptop".activationPackage.drvPath'
nix eval --raw '.#homeConfigurations."pi@Home-Server".activationPackage.drvPath'
nix eval --raw '.#homeConfigurations."afresquet@Alvaros-Mac-mini".activationPackage.drvPath'
nix eval --raw '.#homeConfigurations."alvaro.fresquet@mac-afresquet".activationPackage.drvPath'
```

Evaluate every configuration a change can reach, not just the one you were
thinking about: everything `hosts/home-base.nix` imports is shared by all five home configs
including the headless Pi, and the Mac mini's system config evaluates the
Pi's whole NixOS config through `piConfig`. To inspect a single option, use
`nix eval --json .#<config>.config.<option.path>`.

If evaluation fails with "Path ... is not tracked by Git", the file is new:
`git add -N` it.

## Layout

```
flake.nix             inputs, hosts, helpers; treefmt formatter and check
utils.nix             module discovery (classModules, importFeatures) and
                      directory-import helpers for pkgs/ and overlays/
hosts/
  settings.nix        options every host sets: hostname, username, desktop,
                      dotfilesDir, shell/terminal/editor/browser, monitors,
                      agentTelegram.enable, ...
  configuration.nix   shared NixOS desktop system config (desktop, laptop)
  home-base.nix       shared by every home config, including the Pi
  home.nix            desktop layer: GUI programs, Hyprland, Stylix
  <host>/             settings.nix + configuration.nix + home.nix per host
modules/              one folder per feature, grouped by purpose:
  nix/                the Nix setup itself: auto-upgrade, dotfiles-sync, nh,
                      agenix, allowedUnfree
  system/             machine basics: boot, locale, network, audio,
                      bluetooth, printing, fonts, ssh, tailscale, ...
  desktop/            the Hyprland session: hyprland, stylix, sddm, waybar,
                      rofi, swaync, mako, hyprlock, ...
  terminal/           emulators (ghostty, foot, ...), shells/, prompt,
                      multiplexer
  cli/                command-line tools
  dev/                development: git, helix, direnv, docker, vscode, ...
  ai/                 claude, codex, copilot, skills/, agent-telegram,
                      issue-agent, ollama
  apps/               GUI applications
  gaming/             steam, lutris, sunshine, ...
  homelab/            the Pi's services: caddy, dashboard, monitoring,
                      pihole, home-assistant, arr, vpn, ...
    <feature>/        one file per platform:
      nixos.nix         NixOS module
      darwin.nix        nix-darwin module
      home.nix          home-manager module
      common.nix        what those share (option declarations), imported
                        by them; never exported on its own
      <class>/default.nix  instead of <class>.nix when a platform needs
                        several files (homelab/monitoring)
      *.nix, data       anything else a feature needs (helper modules it
                        imports, JSON, CSS), not exported on its own
pkgs/                 custom packages -> packages.<system> and the
                      `additions` overlay
overlays/             patches to nixpkgs packages -> `modifications` overlay
secrets/              agenix: keys.nix (public keys), agenix-rules.nix, *.age
```

A feature's platforms live side by side, e.g.
`modules/nix/auto-upgrade/{nixos,darwin,home}.nix` or
`modules/ai/agent-telegram/{common,nixos,darwin,home}.nix`; a single-platform
feature is a folder with one file (`modules/gaming/steam/nixos.nix`). A folder
with no platform file and no `common.nix` is a subcategory
(`modules/terminal/shells/`), exported as one module that imports its
features. Pick the category by what the feature is for, not by platform.

`utils.classModules` builds one flake output per platform from that tree:
`outputs.nixosModules`, `darwinModules` and `homeModules`, each
`<category>.<feature>` plus `<category>.default` (the whole category, in
directory order); a category only appears for a platform it has files for.
Creating `modules/<category>/<feature>/<class>.nix` is enough to register it.

Hosts import whole categories (`outputs.nixosModules.<category>.default`) or
single features (`outputs.nixosModules.<category>.<feature>`; the Pi picks its
services this way):

- `hosts/configuration.nix` (NixOS desktops) and `hosts/mac-mini` import every
  category their platform has.
- `hosts/home-base.nix` (every home config) imports the categories that work
  without a graphical session: nix, system, cli, ai, and terminal and dev
  minus their GUI apps (ghostty, herdr-desktop, insomnia), which it lists by
  name. A new GUI app in terminal or dev goes on that list.
- `hosts/home.nix` (desktop layer) adds desktop, apps and gaming, and the
  whole of terminal and dev; the parts home-base already imported are the
  same paths, so the module system imports them once.

Module import order follows category and directory order, and it decides the
order of merged lists (`home.packages`, `environment.systemPackages`,
activation snippets of equal priority). Package order doesn't matter, but
order-sensitive text does: give such snippets an explicit
`lib.mkBefore`/`mkAfter`/`mkOrder` instead of relying on where the module
sits (see `homelab/monitoring/darwin`).

## Module conventions

Every module follows the same shape; copy an existing neighbour.

```nix
{ lib, config, pkgs, ... }:
let
  cfg = config.<name>;
in
{
  options.<name>.enable = lib.mkEnableOption "<Thing>" // {
    default = true;          # or false, isLinux, config.desktop, ...
  };

  config = lib.mkIf cfg.enable {
    # ...
  };
}
```

- Options are top-level (`steam.enable`, not `programs.steam.enable`), named
  after the feature folder, and the same name on every platform
  (`autoUpgrade` in its nixos, darwin and home files). Declarations every
  platform shares go in the feature's `common.nix`, which each platform file
  imports (`imports = [ ./common.nix ]`). Defaults encode where the thing belongs: `true` for every
  host, `isLinux` for Wayland-only tools, `config.desktop` for anything that
  needs a graphical session (the Pi sets `desktop = false`), `false` for
  opt-in.
- Home-manager modules receive `isLinux`, `isDarwin`, `inputs`, `outputs` and
  `utils` as module arguments. NixOS and darwin modules receive `inputs` and
  `outputs`.
- Unfree packages: append the package name to `allowedUnfree` inside the
  module instead of setting `allowUnfree`. The flake carries a NixOS host's
  list into its home config as `nixosAllowedUnfree`.
- The system and home configs are separate evaluations (standalone
  home-manager), so a home module can't read the system's config. A switch
  both sides need declares its option in `hosts/settings.nix` instead, which
  every system and home config imports: the host sets it once in
  `hosts/<host>/settings.nix` and both read it (`agentTelegram.enable`).
- Per-host facts (hostname, user, monitors, dotfiles path) come from
  `config.<setting>` declared in `hosts/settings.nix`. Don't hardcode
  `/home/<user>`, `~/dotfiles` or the wallpaper path; use
  `config.users.users.${config.username}.home`, `config.dotfilesDir`,
  `config.wallpaper`.
- Prefer the upstream module (`programs.*`, `services.*`) over installing a
  package and writing config by hand. Prefer `lib.getExe` / `lib.getExe'`
  over `${pkg}/bin/name`.
- Theming reads from Stylix: `config.stylix.fonts.monospace.name`,
  `config.lib.stylix.colors`, `config.stylix.icons.dark`. Don't repeat font or
  colour names as literals.

### Pi services talk to each other through options

The NixOS modules under `modules/homelab/` contribute to each other instead
of knowing each other's internals:

| Option | Declared in | What it does |
|--------|-------------|--------------|
| `reverseProxy.services.<name>` | `caddy/nixos.nix` | Caddy vhost + blackbox probe URL |
| `dashboard.services.<name>` | `dashboard/nixos.nix` | Homepage tile and widget |
| `monitoring.exporters.<name>` | `monitoring/nixos/options.nix` | Prometheus scrape job + firewall hole |
| `monitoring.dashboards.<name>` | `monitoring/nixos/options.nix` | Grafana dashboard provisioning |

A module that contributes to one of these imports the file that declares it
(`../caddy/nixos.nix`, `../dashboard/nixos.nix`,
`../monitoring/nixos/options.nix`, `../vpn/nixos.nix`). Import
`monitoring/nixos/options.nix`, never `monitoring/nixos/default.nix`, from a
contributor: default.nix imports caddy and dashboard, and the module system
does not tolerate import cycles. Gate monitoring contributions on
`config.monitoring.enable`. Grafana dashboard JSON lives in
`modules/homelab/monitoring/dashboards/` (`export-grafana-dashboard` writes there).

The Mac mini reads these options from the Pi's evaluated config (`piConfig`)
to generate its Prometheus and Grafana provisioning, so a new exporter or
dashboard is a one-module change on the Pi side.

### Workspaces

Hyprland named workspaces are declared once in `hyprland.workspaces` (icon +
`extraRules`) in `modules/desktop/hyprland/home.nix`; Waybar icons and
workspace rules derive from it. Hosts set per-monitor rules through
`hyprland.workspaces.<name>.extraRules`. Keybinds and launch commands live in
the `bind` section of the same file.

### Overlays and version pins

Overlays in `overlays/` patch a specific nixpkgs version and `throw` with a
reminder when the version changes; some modules carry an `assertions` entry
that fires when an upstream fix lands (see the `codex`, `anki` and
`avahi` features). When one of these fires after a flake update, do what the
message says (check upstream, then remove the patch or assertion); don't
silence it.

`nixos-raspberrypi` and `hyprland` deliberately don't follow `nixpkgs` so
their binary caches hit.
The Pi's system runs the stable nixpkgs `nixos-raspberrypi` pins while its home
config uses unstable (stable lacks claude-code, hunk, herdr-core).

## Secrets

`secrets/agenix-rules.nix` maps each `.age` file to the public keys that can
decrypt it (the user key plus the host key of every machine that needs it).
Adding a secret: add the rule, `agenix -e <name>.age` from `secrets/` (user runs
this), `git add -N`, reference it as `age.secrets.<name>.file` in the module
that needs it. Never print or commit decrypted contents. `keys.nix` holds
public keys only.

## Platform notes

- nix-darwin runs only its fixed activation slots. Custom
  `system.activationScripts.<name>` entries are silently ignored; append to
  `postActivation.text` with `lib.mkAfter`.
- launchd daemons that run Nix store binaries wrap `ProgramArguments` in
  `/bin/sh -c '/bin/wait4path "$0" && exec "$0" "$@"'` because `/nix` mounts
  late at boot. Copy the pattern from `modules/homelab/monitoring/darwin`.
- The Mac mini is headless; changes to it are applied over Screen Sharing or
  SSH by the user. `programs.nh` is NixOS-only; on Macs `nh` is a home-manager
  package.
- Home-manager is standalone everywhere (not the NixOS module). It
  instantiates nixpkgs itself, which is why NixOS and home-manager keep
  separate unfree lists.
- The Pi's login shell is bash (for ssh tooling) and hands off to nushell
  interactively; the Macs do the same from zsh. Keep `terminal/shells/bash` and `zsh`
  handoff logic intact when touching shells.
- `hosts/home-server/README.md` is the post-install runbook for the Pi's
  services, including the VPN namespace addressing rules. Read it before
  changing anything under `modules/homelab/` or `modules/system/` that touches networking.

## Style

- nixfmt formatting (`nix fmt`), no `with lib;` or `with pkgs;` at file scope,
  `inherit` where statix suggests it, no unused lambda arguments.
- Comments explain why, not what: the reason a workaround exists, the upstream
  issue number, what breaks without it. Keep that standard.
- Commit messages are short lowercase summaries (`hyprland keybinds`,
  `flake update`), no attribution trailers.
