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
thinking about: `homeManager.base` is shared by all five home configs
including the headless Pi, and the Mac mini's system config evaluates the
Pi's whole NixOS config through `piConfig`. To inspect a single option, use
`nix eval --json .#<config>.config.<option.path>`.

A change that shouldn't alter what a machine runs (moving files, splitting an
aspect, changing who imports what) should leave its derivation paths
unchanged: record them before, compare after. When they differ, compare with
`nix run nixpkgs#nix-diff -- <old>.drv <new>.drv`. The module system merges
list options in import order, so moving an import can reorder
`environment.systemPackages` or `home.packages` (harmless unless two packages
ship the same file) or the lines of a generated shell config (where order can
matter).

If evaluation fails with "Path ... is not tracked by Git", the file is new:
`git add -N` it.

## Layout

The flake is dendritic: `flake.nix` only declares inputs and hands every
`.nix` file under `modules/` to flake-parts through import-tree. Each of those
files is a flake-parts module; paths with a `_`-prefixed component are
skipped, which is where non-module files (hardware configs, dashboards, YAML)
live. Directories are only organisation: moving a file changes nothing.

```
flake.nix               inputs; outputs = mkFlake (import-tree ./modules)
modules/
  flake/                the frame: systems, formatter, packages + overlays,
                        apps, the darwinConfigurations output
  meta.nix              flake-level values any file can read (tailnet,
                        wallpaper, SSH public keys)
  roles/                aspects that are sets of other aspects: nixos.base,
                        nixos.desktop, homeManager.{base,desktop,linux-desktop}
  hosts/<host>.nix      one machine: its system and home configurations
  hosts/_<host>/        its non-module files (hardware config, Home
                        Assistant packages, the Pi's runbook)
  cli/ programs/ services/ gaming/ desktop/ polyfills/
                        aspects, one concern per file, whatever platforms
                        it spans
pkgs/                   custom packages -> packages.<system>, `additions`
overlays/               patches to nixpkgs packages -> `modifications`
secrets/                agenix: keys.nix (public keys), agenix-rules.nix, *.age
```

## Aspects

An aspect is one concern (Tailscale, the issue agent, Hyprland) in one file,
which publishes a module for each platform it touches through flake-parts'
`flake.modules.<class>.<name>`, class `nixos`, `darwin` or `homeManager`:

```nix
# modules/programs/docker.nix
{ self, ... }:
{
  flake.modules.nixos.docker =
    { config, ... }:
    {
      imports = [ self.modules.nixos.primary-user ];

      config = {
        virtualisation.docker.enable = true;

        users.extraGroups.docker.members = [ config.system.primaryUser ];
      };
    };
}
```

- **No enable options.** Importing an aspect is what turns it on. Options are
  for real choices a host makes (`autoUpgrade.dates`, `hyprlock.fingerprint`,
  `waybar.laptop`), not for switching the aspect itself.
- **Adding an aspect**: create the file anywhere under `modules/`, publish
  `flake.modules.<class>.<name>`, `git add -N` it. Nothing registers it; it
  stays unused until something imports it.
- **Giving a host an aspect**: add it to the host's `imports` in
  `modules/hosts/<host>.nix` (they are written inside
  `with self.modules.<class>; [ ... ]`, so just its name), or to a role in
  `modules/roles/` when every host of that role should have it.
- **Dependencies**: an aspect that can't work without another imports it
  (`tilth` imports `skills`, whose option it sets; `hyprland` imports the
  terminal and browser its keybinds launch; Pi services import `caddy` and
  `dashboard` to contribute to them). flake-parts sets no `key` on the modules
  it publishes, so an aspect imported from more than one place carries
  `key = "self.modules.<class>.<name>";`, which makes the module system
  evaluate it once. Without it a second import defines everything twice
  (duplicate list entries, conflicting values).
- **Integrations** (do X only when the host also has Y) test whether Y's
  options exist, never Y's config: auto-upgrade reports through Telegram when
  the agent-telegram aspect is there (`default = options ? agentTelegram;`),
  Pi services contribute exporters when the monitoring aspect is there
  (`lib.hasAttrByPath [ "monitoring" "serverHost" ] options`) and run in the
  VPN namespace when the vpn aspect is there (`options ? vpn`). Options are
  fixed by the imports alone, so these checks can decide what a module
  defines; reading `config.services.foo.enable` from a module that defines
  the same attrset is infinite recursion.
- **Values an aspect's platforms share** go in the file's `let` (the
  tailscale options module, the issue agent's webhook port, the Helix settings
  that also build the `hx` package).
- **Platform**: in home-manager, test `pkgs.stdenv.hostPlatform.isLinux` /
  `isDarwin` inside `config` (`lib.mkIf`), never to choose `imports`.
- **Unfree packages**: import `self.modules.<class>.allowed-unfree` and
  append the package name to `allowedUnfree` instead of setting
  `allowUnfree`. A NixOS host passes its list to its home config as
  `nixosAllowedUnfree`, since standalone home-manager instantiates its own
  nixpkgs.
- **The machine's user** is `config.system.primaryUser` in NixOS and darwin
  modules (on NixOS, import `self.modules.nixos.primary-user`, which declares
  it), and `config.home.username` / `config.home.homeDirectory` in
  home-manager. The checkout is `"${config.home.homeDirectory}/dotfiles"`.
  Don't hardcode `/home/<user>`.
- Prefer the upstream module (`programs.*`, `services.*`) over installing a
  package and writing config by hand. Prefer `lib.getExe` / `lib.getExe'`
  over `${pkg}/bin/name`, and take another program's package from its module
  (`config.programs.ghostty.package`) instead of naming it twice.
- Theming reads from Stylix: `config.stylix.fonts.monospace.name`,
  `config.lib.stylix.colors`, `config.stylix.icons.dark`. Don't repeat font or
  colour names as literals.

### Roles

`modules/roles/` holds aspects whose job is importing others:

| Aspect | Imports | Used by |
|--------|---------|---------|
| `nixos.base` | allowed-unfree, primary-user, auto-upgrade, avahi, bluetooth, ssh, tailscale; the overlays | every NixOS host |
| `nixos.desktop` | `base`, GUI programs, gaming, audio, SDDM, Hyprland, ... | desktop, laptop |
| `homeManager.base` | terminal tooling, shells, dotfiles-sync | every home, the Pi included |
| `homeManager.desktop` | `base`, Stylix, alacritty, kitty, insomnia | every graphical home, Macs included |
| `homeManager.linux-desktop` | `desktop`, Hyprland and its programs, auto-upgrade | desktop, laptop |

Defined but imported by nothing today: fish, eza, gitui, mako,
apprenticevr, kanata, ollama, lutris, bottles, nautilus.

### Hosts

`modules/hosts/<host>.nix` defines `flake.nixosConfigurations.<host>` (or
`darwinConfigurations`) and `flake.homeConfigurations."<user>@<host>"`
directly with `nixpkgs.lib.nixosSystem` (`nixos-raspberrypi.lib.nixosSystem`
for the Pi), `nix-darwin.lib.darwinSystem` and
`home-manager.lib.homeManagerConfiguration`. There are no `specialArgs`:
modules get `inputs` and `self` from the file they are written in. Each
configuration is one inline module that imports its aspects and sets what is
particular to the machine:

- system: `networking.hostName`, `system.primaryUser`, the user's
  description and authorized keys, hardware;
- home: `home.username`, `autoUpgrade.configuration` (its own
  `homeConfigurations` name, which the upgrade timer switches to),
  `agentTelegram.hostName`, `hyprland.monitors` and workspace placement.

A NixOS desktop's home config takes the system's `pkgs` (for its overlays) and
its `allowedUnfree`; the Pi's and the Macs' home configs import nixpkgs with
the two overlays themselves (the Pi's system is on stable nixpkgs, its home on
unstable).

### Sharing values

- **Between the platforms of one aspect**: the file's `let`.
- **Between aspects and hosts**: an option in `modules/meta.nix`, read as
  `config.meta.<name>` from the flake-parts `config` the file receives. Bind
  it in the file's `let` (`inherit (config) meta;`), because a module's own
  `config` argument shadows it. Today: `meta.tailnet` (MagicDNS suffix),
  `meta.wallpaper`, `meta.keys`.
- **Between configurations**: through `self`. The Mac mini's monitoring
  reads `self.nixosConfigurations.Home-Server.config` as `piConfig`; NixOS
  hosts' home configs read their system's `allowedUnfree`.

### Pi services talk to each other through options

The Pi's service aspects contribute to each other instead of knowing each
other's internals:

| Option | Declared in | What it does |
|--------|-------------|--------------|
| `reverseProxy.services.<name>` | `nixos.caddy` | Caddy vhost + blackbox probe URL |
| `dashboard.services.<name>` | `nixos.dashboard` | Homepage tile and widget |
| `monitoring.exporters.<name>` | `services/monitoring/_nixos-options.nix` | Prometheus scrape job + firewall hole |
| `monitoring.dashboards.<name>` | `services/monitoring/_nixos-options.nix` | Grafana dashboard provisioning |

A contributor imports the aspect that declares the option
(`self.modules.nixos.caddy`, `self.modules.nixos.dashboard`; both carry a
`key`) or, for monitoring, the options file by path
(`./monitoring/_nixos-options.nix`), never the monitoring aspect itself: that
one runs the exporters and imports caddy and dashboard. Gate monitoring
contributions on `lib.hasAttrByPath [ "monitoring" "serverHost" ] options`
(the monitoring aspect declares `serverHost`). The Mac mini builds its
Prometheus and Grafana provisioning from the Pi's evaluated options, so a new
exporter or dashboard is a one-file change on the Pi side.

### Workspaces

Hyprland named workspaces are declared once in `hyprland.workspaces` (icon +
`extraRules`) in `modules/desktop/hyprland.nix`; Waybar icons and workspace
rules derive from it. Hosts set `hyprland.monitors` and per-monitor rules
through `hyprland.workspaces.<name>.extraRules`. Keybinds and launch commands
live in the `bind` section of the same file.

### Overlays and version pins

Overlays in `overlays/` patch a specific nixpkgs version and `throw` with a
reminder when the version changes; some aspects carry an `assertions` entry
that fires when an upstream fix lands (see `codex.nix`, `anki.nix`,
`herdr.nix`, `avahi.nix`). When one of these fires after a flake update, do
what the message says (check upstream, then remove the patch or assertion);
don't silence it.

`nixos-raspberrypi` and `hyprland` deliberately don't follow `nixpkgs` so
their binary caches hit.
The Pi's system runs the stable nixpkgs `nixos-raspberrypi` pins while its home
config uses unstable (stable lacks claude-code, hunk, herdr-core).

## Secrets

`secrets/agenix-rules.nix` maps each `.age` file to the public keys that can
decrypt it (the user key plus the host key of every machine that needs it).
Adding a secret: add the rule, `agenix -e <name>.age` from `secrets/` (user runs
this), `git add -N`, reference it as `age.secrets.<name>.file` in the aspect
or host that needs it. Never print or commit decrypted contents. `keys.nix`
holds public keys only; aspects and hosts read them as `config.meta.keys`.

## Platform notes

- nix-darwin runs only its fixed activation slots. Custom
  `system.activationScripts.<name>` entries are silently ignored; append to
  `postActivation.text` with `lib.mkAfter`.
- launchd daemons that run Nix store binaries wrap `ProgramArguments` in
  `/bin/sh -c '/bin/wait4path "$0" && exec "$0" "$@"'` because `/nix` mounts
  late at boot. Copy the pattern from `modules/services/monitoring/_darwin-*.nix`.
- The Mac mini is headless; changes to it are applied over Screen Sharing or
  SSH by the user. `programs.nh` is NixOS-only; on Macs `nh` is a home-manager
  package.
- Home-manager is standalone everywhere (not the NixOS module). It
  instantiates nixpkgs itself, which is why NixOS and home-manager keep
  separate unfree lists.
- The Pi's login shell is bash (for ssh tooling) and hands off to nushell
  interactively; the Macs do the same from zsh. Keep the handoff in the
  `bash` and `zsh` aspects intact when touching shells.
- `modules/hosts/_home-server/README.md` is the post-install runbook for the
  Pi's services, including the VPN namespace addressing rules. Read it before
  changing a Pi service aspect that touches networking.

## Style

- nixfmt formatting (`nix fmt`), no `with lib;` or `with pkgs;` at file scope,
  `inherit` where statix suggests it, no unused lambda arguments.
- Comments explain why, not what: the reason a workaround exists, the upstream
  issue number, what breaks without it. Keep that standard.
- Commit messages are short lowercase summaries (`hyprland keybinds`,
  `flake update`), no attribution trailers.
