# dotfiles

Nix flake for every machine I use: two NixOS desktops, a Raspberry Pi
home server, a headless Mac mini on nix-darwin, and a work MacBook that
only gets home-manager.

| Host | Platform | System config | Home config |
|------|----------|---------------|-------------|
| `Alvaro-Desktop` | NixOS, x86_64 | `nixosConfigurations.Alvaro-Desktop` | `homeConfigurations."afresquet@Alvaro-Desktop"` |
| `Alvaro-Laptop` (Framework 13) | NixOS, x86_64 | `nixosConfigurations.Alvaro-Laptop` | `homeConfigurations."afresquet@Alvaro-Laptop"` |
| `Home-Server` (Raspberry Pi 5) | NixOS, aarch64 | `nixosConfigurations.Home-Server` | `homeConfigurations."pi@Home-Server"` |
| `Alvaros-Mac-mini` | nix-darwin, aarch64 | `darwinConfigurations.Alvaros-Mac-mini` | `homeConfigurations."afresquet@Alvaros-Mac-mini"` |
| `mac-afresquet` (work MacBook) | nix-darwin, aarch64 | `darwinConfigurations.mac-afresquet` | `homeConfigurations."alvaro.fresquet@mac-afresquet"` |

## Layout

The flake is [dendritic](https://github.com/mightyiam/dendritic): every
`.nix` file under `modules/` is a flake-parts module, loaded by import-tree,
and `flake.nix` only lists inputs.

- Each file is an *aspect*: one concern (Tailscale, Hyprland, the issue
  agent) publishing a module per platform it touches as
  `flake.modules.{nixos,darwin,homeManager}.<name>`. There are no enable
  options: a machine has an aspect because its configuration imports it.
- `modules/roles/` holds aspects that group others: `nixos.base`,
  `nixos.desktop`, `homeManager.base` (every home, the Pi included),
  `homeManager.desktop` (every graphical home) and
  `homeManager.linux-desktop` (Hyprland).
- `modules/hosts/<host>.nix` builds a machine's system and home
  configurations from aspects and sets what is particular to it; its
  hardware config and other plain files sit in `modules/hosts/_<host>/`.
- `modules/meta.nix` holds values shared across files (tailnet suffix,
  wallpaper, SSH public keys).
- The Pi's services contribute to each other through
  `reverseProxy.services`, `dashboard.services`, `monitoring.exporters` and
  `monitoring.dashboards`. The Mac's monitoring reads the Pi's evaluated
  config (`piConfig`) to build its Prometheus and Grafana provisioning.
- `pkgs/` are custom packages exposed as `packages.<system>` and through the
  `additions` overlay; `overlays/` holds patches to nixpkgs packages, each of
  which throws once the pinned version moves so it gets removed.
- `secrets/` is agenix: `keys.nix` lists the public keys, `agenix-rules.nix`
  says which keys decrypt which secret.

`AGENTS.md` covers adding an aspect, giving a host one, and sharing values.

## Rebuilding

The `nh` aliases from `modules/cli/nh.nix`, run from anywhere:

| Alias | Runs |
|-------|------|
| `noss` / `nost` / `nosb` | `nh os switch` / `test` / `boot` |
| `ndws` | `nh darwin switch` |
| `nhms` | `nh home switch` |
| `nca` | `nh clean all` |

The flake path is `~/dotfiles`. The Pi's SD image is built by the GitHub workflow in
`.github/workflows/build-home-server.yml`; `modules/hosts/_home-server/README.md` is
the post-install checklist for its services.

## Secrets

```sh
cd secrets
agenix -e <name>.age
```

New secrets get an entry in `agenix-rules.nix` first, then `git add` so the
flake sees the file. Host keys come from `/etc/ssh/ssh_host_ed25519_key.pub`
on each box.

## Checks

`nix fmt` formats with nixfmt and `nix flake check` also runs statix and
deadnix (via treefmt-nix).
