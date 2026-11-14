# Auto-upgrade start/finish messages through the machine's agent-telegram bot.
# An integration of two aspects a host can have independently (the desktops
# upgrade without a bot), so a host imports this to join them.
{ self, ... }:
let
  telegram = class: {
    imports = [
      self.modules.${class}.auto-upgrade
      self.modules.${class}.agent-telegram
    ];

    autoUpgrade.telegram = true;
  };
in
{
  flake.modules.nixos.auto-upgrade-telegram = telegram "nixos";
  flake.modules.darwin.auto-upgrade-telegram = telegram "darwin";
  flake.modules.homeManager.auto-upgrade-telegram = telegram "homeManager";
}
