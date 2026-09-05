{ config, pkgs, lib, ... }:

{
  # OOM handling
  systemd.oomd.enable = false;

  services.earlyoom.enable = true;

  # aurelia-daemon fix

  systemd.user.services.aurelia-daemon = {
   description = "Aurelia Steam CLI daemon";
   
   wantedBy = [ "graphical-session.target" ];

   environment = {
     LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
     PATH = lib.mkForce "/run/current-system/sw/bin:/home/bradley/.nix-profile/bin";
   };

   serviceConfig = {
     ExecStart = "/home/bradley/.nix-profile/bin/aurelia daemon";
     Restart = "on-failure";
     RestartSec = 2;
   };
  };

  # lid behaviour
  services.logind.settings.Login = {
    HandleLidSwitch = "poweroff";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # snapper
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

  # networking
  networking.networkmanager.enable = true;

  # audio
  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  security.rtkit.enable = true;

  # locate
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "weekly";
  };

  # memory compression
  zramSwap.enable = true;

  # SSD maintenance
  services.fstrim.enable = true;

  # power management
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;

    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      RADEON_DPM_PERF_LEVEL_ON_AC = "high";
      RADEON_DPM_PERF_LEVEL_ON_BAT = "low";

      CPU_BOOST_ON_AC="1";
      CPU_BOOST_ON_BAT="0";

      SATA_LINKPWR_ON_AC="med_power_with_dipm";

      AHCI_RUNTIME_PM_ON_AC="on";
      AHCI_RUNTIME_PM_ON_BAT="auto";

      AMDGPU_ABM_LEVEL_ON_AC="0";
      AMDGPU_ABM_LEVEL_ON_BAT="2";

      WIFI_PWR_ON_AC="off";
      WIFI_PWR_ON_BAT="on";
 
      WOL_DISABLE="Y";
    };
  };

  # desktop filesystem
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;
  services.tumbler.enable = true;

  security.polkit.enable = true;

  # firmware updates
  services.fwupd.enable = true;
}
