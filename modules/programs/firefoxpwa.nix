{
  flake.modules.homeManager.firefoxpwa = _: {
    config = {
      programs.firefoxpwa = {
        enable = true;

        profiles."058RVBQ3TDP7KCBRNSFBTHPYG5".sites = {
          "5WZA9TCY3FCFNEYGJ7R8YH1Y2T" = {
            name = "WhatsApp";
            url = "https://web.whatsapp.com/";
          };
          "34A57P959JZJSVEG8BGEMTQC7R" = {
            name = "X";
            url = "https://x.com/";
          };
          "5MHDMZSV8N0EQA4TAVFAK8KPG1" = {
            name = "Apple Music";
            url = "https://music.apple.com/";
          };
        };
      };
    };
  };
}
