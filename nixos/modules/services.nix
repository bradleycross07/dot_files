{ config, pkgs, ... }:

{
  # OOM handling
  systemd.oomd.enable = false;

  services.earlyoom.enable = true;

  # Lid behaviour
  services.logind.settings.Login = {
    HandleLidSwitch = "poweroff";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # Snapper
  services.snapper = {
    configs = {
      root = {
        SUBVOLUME = "/";
        ALLOW_USERS = [ "bradley" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "5";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY = "2";
      };

      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ "bradley" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "5";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY = "2";
      };
    };
  };

  # Networking
  networking.networkmanager.enable = true;

  # Audio
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.rtkit.enable = true;

  # Locate
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "weekly";
  };

  # Memory compression
  zramSwap.enable = true;

  # SSD maintenance
  services.fstrim.enable = true;

  # Power management
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;

    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    };
  };

  # Desktop filesystem / device integration
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;
  services.tumbler.enable = true;

  security.polkit.enable = true;

  # Firmware updates
  services.fwupd.enable = true;
}
