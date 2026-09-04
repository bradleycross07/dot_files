{ config, pkgs, pkgs-unstable, ... }:

{
  # wayland compositor
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "mango";
    XDG_SESSION_TYPE = "wayland";
  };

  # main packages for the system
  environment.systemPackages = with pkgs; [
    pkgs-unstable.mangowc
    pkgs-unstable.kanshi
    pkgs-unstable.wlr-randr

    xwayland
    waylock
    swayidle
    swaybg

    wl-clipboard
    grim
    slurp
    brightnessctl
    fuzzel
    playerctl

    imv
    mpv

    nwg-look
    xlsclients

    bibata-cursors
    papirus-icon-theme

    # waybar (compiled to latest version for mango)
    ((pkgs-unstable.waybar.override {
	cavaSupport = false;
    }).overrideAttrs (old: {
	doInstallCheck = false;
	version = "unstable-2026-08-27";

	src = pkgs.fetchFromGitHub {
	owner = "Alexays";
	repo = "Waybar";
	rev = "6d60c8e02be67bb85bb9b1ea803f2fbcf0722002";
	hash = "sha256-G6AcGuevhkYflQHhJq9GnLhEMgcI51Y6MYKBQvdRPDc=";
    };

    mesonFlags = old.mesonFlags ++ [
    "-Dwwan=disabled"
    ];
    }))
  ];

  # desktop portals (allow screensharing)
  xdg.portal = {
    enable = true;
    wlr.enable = true;

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];

    config = {
      common.default = "*";
      common."org.freedesktop.impl.portal.ScreenCast" = "wlr";
    };

    wlr.settings.screencast = {
      chooser_type = "simple";
      chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
    };
  };

  # desktop integration
  programs.dconf.enable = true;
  programs.xfconf.enable = true;

  # seat management
  services.seatd.enable = true;

  # GNOME keyring
  services.gnome.gnome-keyring.enable = true;

  # waylock PAM
  security.pam.services.waylock = { };
}
