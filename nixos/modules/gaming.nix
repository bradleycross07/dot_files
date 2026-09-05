{ config, pkgs, pkgs-unstable, ... }:

{
  hardware.steam-hardware.enable = true;
  
  hardware.graphics.extraPackages = [ pkgs-unstable.mangohud ];
  hardware.graphics.extraPackages32 = [ pkgs-unstable.pkgsi686Linux.mangohud ];

  programs.gamemode = {
    enable = true;

    settings = {
      general.renice = 10;

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 1;
        amd_performance_level = "high";
      };
    };
  };

  programs.gamescope = {
    enable = true;
    package = pkgs-unstable.gamescope;
  };

  services.scx = {
    enable = true;
    package = pkgs-unstable.scx.full;
    scheduler = "scx_lavd";
  };
}
