# Home-Server: post-rebuild manual setup

Everything in this host's Nix config gets you to "services running, ports
firewalled, secrets decrypted, reverse proxy serving." Each app on top of that
manages its own state in its own database, so a few things have to be clicked
through in the web UIs the first time. This file is the checklist.

All hostnames below assume you're hitting them from a Tailscale-connected
device, with Pi-hole acting as the tailnet DNS.

## 0. Disk

`/mnt/hdd` is mounted from `/dev/sda1` (label `hdd`). If you ever need to wipe
and recreate the partition:

```sh
sudo wipefs -a /dev/sda
sudo sgdisk --zap-all /dev/sda
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:"hdd" /dev/sda
sudo partprobe /dev/sda
sudo mkfs.ext4 -F -L hdd /dev/sda1
```

The `hdd` label is what `fileSystems."/mnt/hdd"` in `configuration.nix`
references, so any new disk just needs that label.

## 1. agenix secrets

Edit each from the dotfiles repo (`EDITOR` is set to Helix via home-manager):

```sh
cd ~/dotfiles/secrets
agenix -e <name>.age
```

| Secret                          | Content                                                    |
|---------------------------------|------------------------------------------------------------|
| `tailscale-auth.age`            | tailscale auth key (`tskey-auth-...`)                      |
| `pihole-webpassword.age`        | `FTLCONF_webserver_api_password=YOUR_PASSWORD`             |
| `qbittorrent-webuipw.age`       | the PBKDF2 hash *only* (see qBittorrent section below)     |
| `mullvad-wg.age`                | full Mullvad WireGuard config (`[Interface]` + `[Peer]`). **Override `DNS = 10.64.0.1` with `DNS = 1.1.1.1`** — Mullvad's own DNS sinkholes torrent indexers to `127.0.0.1`. See VPN namespace section below. |

After creating any new `.age` file: `git add` it so the flake can see it, then
`nixos-rebuild switch`.

## 2. Tailscale tailnet DNS

In the [Tailscale admin console](https://login.tailscale.com/admin/dns):

- **DNS → Nameservers → Add nameserver → Custom**: the Pi's tailscale IP
  (find with `tailscale ip -4` on the Pi — currently `100.85.40.30`)
- Toggle **Override local DNS** on

This makes all tailnet clients route DNS through Pi-hole. The
`pihole.home-server`, `home-assistant.home-server`, etc. records are generated
declaratively via `FTLCONF_dns_hosts`, so no Pi-hole UI clicking needed.

## 3. Router (Livebox 7)

- Admin UI: `http://192.168.1.1` → Advanced settings → DHCP → Static leases
- Add a reservation for the Pi's wired MAC (`ip -br link show eth0` on Pi).
- Pick an IP outside the dynamic DHCP pool.

## 4. Pi-hole

Reachable as `http://home-server/` (Tailscale MagicDNS aliases bare hostname to
the Pi-hole vhost) or `http://pihole.home-server/`.

- Login password is whatever's in `pihole-webpassword.age`.
- No other config required — DNS records, upstreams, listening mode all
  declarative in `modules/nixos/services/pihole.nix`.

## 5. Home Assistant

URL: `http://home-assistant.home-server/`

1. First-run wizard: create admin user, pick location/timezone.
2. Skip integration prompts — set those up later.
3. Add the trusted-proxy block to `/var/lib/home-assistant/configuration.yaml`
   so HA accepts requests from caddy:

   ```sh
   sudo tee -a /var/lib/home-assistant/configuration.yaml > /dev/null <<'EOF'

   http:
     use_x_forwarded_for: true
     trusted_proxies:
       - 127.0.0.1
   EOF
   sudo systemctl restart podman-home-assistant.service
   ```

   (HA is the container-based service in this stack; everything else is native.)

## 6. qBittorrent

URL: `http://torrent.home-server/`

First-time password bootstrap (only needed for the very first run, or if you
ever wipe `qbittorrent-webuipw.age`):

1. Get the temp password from the journal:

   ```sh
   journalctl -u qbittorrent.service | grep -i 'temporary password'
   ```

2. Log in with `admin` + temp password.
3. **Tools → Options → Web UI → Authentication**: set your real password, save.
4. Read the resulting PBKDF2 hash from the on-disk config:

   ```sh
   sudo grep 'Password_PBKDF2' /mnt/hdd/qbittorrent/qBittorrent/config/qBittorrent.conf
   ```

   You'll see something like:
   `WebUI\Password_PBKDF2="@ByteArray(salt:hash)"`.
5. `agenix -e ~/dotfiles/secrets/qbittorrent-webuipw.age` and paste **only** the
   content between `@ByteArray(` and `)` — *not* the `@ByteArray(...)` wrapper
   or the surrounding quotes. One line, no trailing newline.
6. `nixos-rebuild switch && sudo systemctl restart qbittorrent.service`.

From now on the password persists across rebuilds — the wrapper module
substitutes the agenix-decrypted hash into `qBittorrent.conf` at start.

Everything else (save path, seeding limits, host header validation, WG
interface binding) is declarative in `modules/nixos/services/qbittorrent.nix`.

**Important:** the qbittorrent module hardcodes `Session\InterfaceAddress` to
the Mullvad-assigned IP for the WireGuard tunnel (currently `10.75.78.187`).
This IP is tied to your Mullvad WireGuard key, *not* the exit server — it stays
stable as long as you don't regenerate the WG key. If you ever rotate the WG
key, read the new `Address = ...` line from the Mullvad config and update the
`Session\InterfaceAddress` value in `qbittorrent.nix`. Without this binding,
qBittorrent silently picks the wrong interface and DHT/peer traffic doesn't go
through Mullvad.

## 7. Jellyfin

URL: `http://jellyfin.home-server/` (or `http://<lan-ip>:8096/` for casting from
TVs / phones on the LAN).

1. First-run wizard: pick language, create admin user.
2. Dashboard → **Libraries → Add Media Library**, one for each type:

   | Display name | Content type | Folder                    |
   |--------------|--------------|---------------------------|
   | Movies       | Movies       | `/mnt/hdd/media/movies`   |
   | TV           | Shows        | `/mnt/hdd/media/tv`       |
   | Music        | Music        | `/mnt/hdd/media/music`    |
   | Books        | Books        | `/mnt/hdd/media/books`    |

3. For each library: **Advanced → ☑ Enable Real-time Monitoring** so new files
   from Sonarr/Radarr/etc. show up within seconds rather than waiting for the
   hourly scan.

## 8. Prowlarr

URL: `http://prowlarr.home-server/`

1. First-run: create user/password.
2. **Indexers → +** → add the trackers you want (1337x, EZTV, YTS, etc.).
   Click **Test** before saving.
3. For Cloudflare-protected indexers (1337x, etc.):
   - **Settings → Indexers → Indexer Proxies → +** → FlareSolverr
   - Name: `flaresolverr`, Host: `http://127.0.0.1:8191`, Tags: add `cf`
   - Edit each protected indexer → add the `cf` tag → save.
   - Note: despite being labeled "FlareSolverr" in Prowlarr's UI, the actual
     backend is **Byparr** (Camoufox-based, far better at current Cloudflare
     protections than FlareSolverr). It runs as a podman container inside the
     wg namespace and exposes the same API on `127.0.0.1:8191`.
4. **Settings → Apps → +** → add each *arr Prowlarr should sync indexers to.
   *Prowlarr lives in the wg namespace and the *arr apps run on the host*, so
   Prowlarr must reach them via the namespace's host-side bridge IP
   `192.168.15.5`:

   | App     | App URL                       | Use *arr's API key from |
   |---------|-------------------------------|-------------------------|
   | Sonarr  | `http://192.168.15.5:8989`    | Sonarr → Settings → General → Security |
   | Radarr  | `http://192.168.15.5:7878`    | same path in Radarr |
   | Lidarr  | `http://192.168.15.5:8686`    | same path in Lidarr |
   | Readarr | `http://192.168.15.5:8787`    | same path in Readarr |

   For all of them, **Prowlarr Server** = `http://192.168.15.1:9696` — that's
   the URL the *arrs on the host use to call back into Prowlarr (host →
   namespace via the bridge's namespace-side IP).

## 9. Sonarr / Radarr / Lidarr / Readarr

Each has its own UI:

| App     | URL                            | Root folder              |
|---------|--------------------------------|--------------------------|
| Sonarr  | `http://sonarr.home-server/`   | `/mnt/hdd/media/tv`      |
| Radarr  | `http://radarr.home-server/`   | `/mnt/hdd/media/movies`  |
| Lidarr  | `http://lidarr.home-server/`   | `/mnt/hdd/media/music`   |
| Readarr | `http://readarr.home-server/`  | `/mnt/hdd/media/books`   |

For **each** app:

1. First-run: create user/password.
2. **Settings → Media Management → Root Folders → +** → add the path from the
   table above.
3. **Settings → Media Management** → toggle **Show Advanced** at the top → verify
   **Use Hardlinks instead of Copy** is checked. (Should be on by default; if
   it's off, hardlinks fall back to copies and disk usage doubles.)
4. **Settings → Download Clients → + → qBittorrent**:
   - Host `192.168.15.1` (not `127.0.0.1` — qBittorrent lives in the wg
     namespace; the host reaches it via the namespace-side bridge IP)
   - Port `8080`
   - Username / Password: the qBittorrent admin credentials from agenix
   - Category: `sonarr` / `radarr` / `lidarr` / `readarr` respectively (the app
     auto-creates the category in qBittorrent)
   - **☑ Remove Completed Downloads** (advanced) — let *arr clean up paused
     torrents via the qBittorrent API after import, rather than qBittorrent
     auto-removing them. Prevents the "qBittorrent is configured to remove
     torrents…" health-check warning.
5. **Settings → Indexers** — should auto-populate from Prowlarr's sync. If not,
   trigger a manual sync from the Prowlarr → Apps page.

### Recovery: lost a Sonarr/Radarr password

```sh
sudo systemctl stop sonarr.service   # or radarr, lidarr, readarr
sudo sed -i 's|<AuthenticationMethod>.*</AuthenticationMethod>|<AuthenticationMethod>None</AuthenticationMethod>|' \
  /var/lib/sonarr/.config/NzbDrone/config.xml
sudo systemctl start sonarr.service
```

Then hit the URL, get into the unauthenticated UI, set a new password under
Settings → General → Security, flip Authentication back to **Forms**.

## 10. Bazarr

URL: `http://bazarr.home-server/`

1. Default login: `admin` / `admin` — **change immediately** in
   Settings → General.
2. **Settings → Sonarr** → enable → URL `http://127.0.0.1:8989`, paste Sonarr's
   API key.
3. **Settings → Radarr** → enable → URL `http://127.0.0.1:7878`, paste Radarr's
   API key.
4. **Settings → Languages**: pick the subtitle languages you want and the
   default profile.
5. **Settings → Providers**: add OpenSubtitles, Subscene, etc. (some need
   accounts).

## 11. Navidrome

URL: `http://navidrome.home-server/`

Subsonic-compatible streaming server pointed at `/mnt/hdd/media/music`. Runs as
the native `navidrome` user (added to the `media` group for read access).

1. First-run: create an admin user (Navidrome stores accounts in
   `/var/lib/navidrome/navidrome.db`).
2. The scanner picks up `/mnt/hdd/media/music` automatically — initial scan
   takes a while if the library is large. Watch progress under **Settings →
   About → Server Status** or via `journalctl -u navidrome -f`.
3. Optional: **Settings → Personal → Last.fm** to scrobble plays.
4. Subsonic clients (DSub, play:Sub, Symfonium, Substreamer, Tempo, etc.):
   server `http://navidrome.home-server`, your admin credentials.

## 12. MusicSeerr

URL: `http://musicseerr.home-server/`

Music request + discovery frontend around Lidarr with a built-in audio player
that can stream from Navidrome / Jellyfin. Runs as a podman container with
`--network=host`, so the URLs below are all host-loopback. State lives under
`/var/lib/musicseerr/{config,cache}`.

1. First-run: create an admin user via the web UI.
2. **Settings → Lidarr**:
   - URL: `http://127.0.0.1:8686`
   - API key: from `http://lidarr.home-server/` → Settings → General → Security.
3. **Settings → Player → Navidrome** (recommended) or **Jellyfin**:
   - Navidrome URL: `http://127.0.0.1:4533`, admin credentials from §11.
   - Jellyfin URL: `http://127.0.0.1:8096`, admin credentials from §7.
4. Optional: **Settings → ListenBrainz / Last.fm** to scrobble plays.

## 13. Jellyseerr

URL: `http://jellyseerr.home-server/`

1. First-run: **Sign in with Jellyfin** → enter
   - Jellyfin URL: `http://127.0.0.1:8096`
   - Username + password: your Jellyfin admin (not a separate Jellyseerr account)
2. **Sync Libraries**: pick all four (Movies, TV, Music, Books).
3. **Settings → Services → Sonarr → +**:
   - Hostname `127.0.0.1`, port `8989`, paste Sonarr's API key
   - Default Quality Profile and Root Folder (`/mnt/hdd/media/tv`)
4. **Settings → Services → Radarr → +**: same with port `7878`, root folder
   `/mnt/hdd/media/movies`.

After this the request loop works end-to-end:

```
Jellyseerr → Sonarr/Radarr → Prowlarr → indexer → qBittorrent
  → /mnt/hdd/downloads/torrents → *arr hardlinks to /mnt/hdd/media/...
  → Jellyfin picks up via real-time monitoring
```

## VPN namespace (Mullvad WireGuard via `vpn-confinement`)

qBittorrent, Prowlarr, and Byparr run inside a Linux network namespace named
`wg` whose only egress is a Mullvad WireGuard tunnel. Tailscale, caddy,
Pi-hole, Home Assistant, Jellyfin, and the *arr orchestrators all run in the
default (host) namespace and are unaffected.

The namespace has its own iptables (default-DROP INPUT, kill switch — if the
tunnel drops, namespaced services lose internet rather than leaking through
the host's interface). vpn-confinement creates a bridge `wg-br` between the
default and `wg` namespaces, with these well-known addresses:

| Address          | Where                                                    |
|------------------|----------------------------------------------------------|
| `192.168.15.1`   | Namespace-side end of the bridge (services in `wg` bind here for callers from the host) |
| `192.168.15.5`   | Host-side end of the bridge (services on the host expose here for callers in the namespace) |
| `10.x.x.x`       | The Mullvad-assigned WG IP, applied to `wg0` inside the namespace |

### Cross-namespace addressing rules

| From → To                                              | Use                       |
|--------------------------------------------------------|---------------------------|
| Host service → namespaced service (Prowlarr, qBittorrent, Byparr) | `192.168.15.1:<port>` |
| Namespaced service → host service (the *arr apps)      | `192.168.15.5:<port>`     |
| Within the same namespace (e.g. Prowlarr → Byparr)     | `127.0.0.1:<port>`        |
| Within the host (e.g. Bazarr → Sonarr)                 | `127.0.0.1:<port>`        |

Whenever a service refuses connections with "Connection refused (localhost:X)",
think about which side of the namespace each end of the connection lives on.
Almost every wiring bug we hit came from using `127.0.0.1` when the two ends
are in different namespaces.

### DNS

The namespace ignores Pi-hole and the host's resolv.conf. It uses what's in
the `[Interface]` `DNS = ...` field of the Mullvad WG config. **That MUST be a
non-filtering resolver — `1.1.1.1` is what we use.** Mullvad's default
`10.64.0.1` actively sinkholes torrent-indexer hostnames (returns `127.0.0.1`),
which causes silent failures like `ERR_CONNECTION_REFUSED` deep inside
FlareSolverr/Byparr.

### nscd is disabled host-wide for this reason

`services.nscd.enable = false` in the host config. Without that, glibc lookups
from any process — including ones inside the namespace — go through the host's
nsncd daemon, which resolves using the host's resolv.conf (the Livebox, which
ISP-poisons torrent sites). Disabling nscd makes each process do its own NSS
lookups in its own namespace.

The upstream NixOS *arr modules still have `InaccessiblePaths=/run/nscd` and
`BindReadOnlyPaths=/run/nscd` baked into their hardening config (assumption
that nscd is always enabled). To satisfy systemd's mount-namespacing, we
create an empty `/run/nscd` via `systemd.tmpfiles.rules`. Don't remove that
rule.

### qBittorrent interface binding (subtle but essential)

qBittorrent inside the namespace doesn't auto-bind to `wg0` — it picks
`veth-wg` (alphabetically first non-loopback), which would send torrent
traffic out the bridge rather than through Mullvad. Three keys in
`serverConfig.BitTorrent` force binding to `wg0`:

```nix
"Session\\Interface" = "wg0";
"Session\\InterfaceName" = "wg0";
"Session\\InterfaceAddress" = "10.75.78.187";  # hardcoded Mullvad WG IP
```

All three are required; setting only `InterfaceName` causes qBittorrent to
silently bind to nothing. The `InterfaceAddress` is the Mullvad-assigned IP
from your WG config's `Address = ...` line — see qBittorrent section above
for what to do if you ever rotate WG keys.

### Cloudflare bypass (Byparr container)

FlareSolverr in nixpkgs can't reliably solve current Cloudflare challenges
(1337x, TPB, etc. fail with timeouts). Byparr (Camoufox-based, FlareSolverr API
compatible) is run as a podman container directly attached to the `wg`
namespace via `--network=ns:/var/run/netns/wg`. Prowlarr's "FlareSolverr"
indexer proxy entry points at `http://127.0.0.1:8191` (namespace-internal) and
the container responds — Prowlarr neither knows nor cares it's Byparr.

The container's lifecycle is bound to `wg.service` so it tears down/restarts
with the namespace.

### Firewall openings

Three places where the firewall is opened for cross-namespace traffic. All
declarative:

- **`networking.firewall.interfaces.wg-br.allowedTCPPorts`** (in `arr.nix`):
  `7878 8989 8686 8787` — so Prowlarr (in namespace) can reach the *arr apps
  on the host via `wg-br`. Not exposed elsewhere.
- **`vpnNamespaces.wg.portMappings`** (in `qbittorrent.nix`, `arr.nix`):
  DNATs PREROUTING for `8080` (qBittorrent UI) and `9696` (Prowlarr UI) so
  external (caddy) traffic can be forwarded into the namespace.
- **`vpnNamespaces.wg.openVPNPorts`** (in `qbittorrent.nix`): accepts inbound
  on `6881` TCP+UDP on `wg0` so DHT replies don't get dropped by the
  namespace's default-DROP INPUT after conntrack expires.

## Notes / gotchas

- **Hardlink ownership**: qBittorrent runs with `UMask=0002` so new files are
  `0664`. Combined with the `2775 root:media` perms on `/mnt/hdd/downloads`,
  this lets the *arr users (in the `media` group) hardlink into
  `/mnt/hdd/media/*` without tripping the kernel's `fs.protected_hardlinks`
  check. Don't change qBittorrent's UMask back to defaults or hardlinks will
  silently fall back to copies.
- **Seeding policy**: 1.0 ratio OR 48h, then **pause** the torrent (not remove).
  Declared in `qbittorrent.nix`. *arr removes the paused torrents via API once
  import completes (each *arr's "Remove Completed Downloads" toggle). Pause
  rather than remove keeps *arr's database consistent — removing behind its
  back triggers a health-check warning.
- **API keys**: not declarative. Each app generates its own on first run; if you
  ever wipe `/var/lib/<app>` you'll have to re-paste them into the apps that
  consume them (Prowlarr → all *arr, Bazarr → Sonarr/Radarr, Jellyseerr →
  Sonarr/Radarr).
- **`home-server` (bare hostname)**: aliased on the Pi-hole vhost in caddy so
  Tailscale MagicDNS users have a path in even when subdomain DNS isn't working
  yet. Don't remove that alias.
- **Tailscale health-check warning** ("Tailscale can't reach the configured DNS
  servers"): cosmetic. The home-server *is* the tailnet DNS (Pi-hole), so when
  the daemon health-checks the configured DNS by querying `100.85.40.30` over
  the tunnel, the request loops back to itself and the health check fails. It
  doesn't affect tailnet clients. Ignore.
- **Mullvad has no port forwarding** (removed in 2023). Torrenting still works
  via DHT and tracker-introduced peers, but no incoming connections from
  internet peers. Means slightly fewer peers per torrent — not noticeable in
  practice for well-seeded content. AirVPN/ProtonVPN still do port forwarding
  if it ever becomes a real bottleneck.
- **VPN exit reputation**: torrent sites blacklist popular Mullvad exit IPs
  (Netherlands especially). Sweden tends to work best in our experience. To
  swap: regenerate the WG config on Mullvad's site for a different country,
  paste into `agenix -e secrets/mullvad-wg.age`, **keep `DNS = 1.1.1.1`**, then
  `nixos-rebuild switch && sudo systemctl restart wg.service`. If the Mullvad
  *server* changes the Mullvad *exit IP* changes too, but **your WG `Address`
  stays the same** (it's per-key, not per-server) — so `qbittorrent.nix`'s
  hardcoded `InterfaceAddress` doesn't need updating unless you rotate keys.
