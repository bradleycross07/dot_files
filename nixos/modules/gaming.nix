{ config, pkgs, pkgs-unstable, ... }:

let
  proton-ge-latest = pkgs.stdenv.mkDerivation {
    pname = "proton-ge-custom";
    version = "GE-Proton11-6";

    src = pkgs.fetchurl {
      url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-6/GE-Proton11-6-x86_64.tar.gz";
      hash = "sha256-ZZ+NcfL3hlk0ASCyDBxaFGSqE4k5MyoTdt6iL20twuQ=";
    };

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };
in

{
  programs.steam = {
    enable = true;

    extraCompatPackages = [
      pkgs.proton-ge-bin
      proton-ge-latest
    ];
  };

  hardware.steam-hardware.enable = true;

  programs.gamemode = {
    enable = true;

    settings = {
      general.renice = 10;

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
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

  hardware.graphics.extraPackages = [
    pkgs-unstable.mangohud
  ];

  hardware.graphics.extraPackages32 = [
    pkgs-unstable.pkgsi686Linux.mangohud
  ];
}
