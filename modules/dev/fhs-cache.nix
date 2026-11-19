# The harvest project's Attic cache on Home-Server (homelab/attic.nix), public
# on the tailnet. Set system-wide because users aren't trusted, so the
# project flake's own `nixConfig` caches would be ignored. Pushing is the
# project's own business: it keeps its push token encrypted in its repo.
{
  flake.modules.darwin.fhs-cache.determinateNix.customSettings = {
    extra-substituters = [ "http://attic.home-server/fhs" ];
    extra-trusted-public-keys = [ "fhs:epSm4+yTNG4yjz7xR0m2l7y8UefOIVhb+tS7yVJvIQo=" ];
  };
}
