{ config, pkgs, ... }:

{
  # system hname & timezone
  networking.hostName = "nixos";
  time.timeZone = "Europe/London";

  # locales
  console.keyMap = "us";
  i18n.defaultLocale = "en_GB.UTF-8";

  # user
  users.users.bradley = {
    isNormalUser = true;
    description = "Bradley";
    extraGroups = [
      "wheel"
      "networkmanager"
      "seat"
      "video"
      "render"
      "input"
    ];
    shell = pkgs.zsh;
  };

  # zsh shell
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    shellAliases = {
      ff = "fastfetch";
      ls = "eza --color=always";
      lt = "eza --tree --color=always";
      cat = "bat";
      nano = "nvim";
      grep = "rg";

      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#nixos";
      rebuild-test = "sudo nixos-rebuild test --flake ~/nixos#nixos";
      rebuild-boot = "sudo nixos-rebuild boot --flake ~/nixos#nixos";
      rebuild-check = "nix flake check ~/nixos";

      du = "dust";
      df = "duf";
      ps = "procs";
    };
  };
  
  # allow compatibility for DLLs
  programs.nix-ld = {
   
   enable = true;
   
   libraries = with pkgs; [
    
    # X11 compatibility
    libX11
    libXext
    libXcursor
    libXi
    libXrandr
    libXinerama
    libXrender
    libxcb
    libXfixes
    libXcomposite
    libXdamage
    libXau
    libXdmcp

    # wayland
    wayland

    # vulkan / graphics
    vulkan-loader
    pkgsi686Linux.vulkan-loader
    libdrm
    mesa

    # Fonts
    freetype
    fontconfig

    # Networking / USB
    libusb1
    gnutls

    # audio
    alsa-lib
    libpulseaudio

    # general runtime libraries
    zlib
    glib
    dbus
    expat
    pango
    cairo
   
   ];
  };

  # environment
  environment.variables.TERMINAL = "kitty";

  environment.pathsToLink = [
    "/libexec"
  ];

  # optimizations for session
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    MESA_SHADER_CACHE_MAX_SIZE = "10G";
    SDL_VIDEODRIVER = "wayland";
    XDG_CURRENT_DESKTOP = "mango";
    XDG_SESSION_TYPE = "wayland";
    BROWSER = "firefox";

    GSETTINGS_SCHEMA_DIR =
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "30";
  };

  # nixos rebuilding settings
  nix.settings = {
    cores = 0;
    max-jobs = "auto";
    auto-optimise-store = true;

    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  
  # automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # jounrald optimisation
  services.journald.extraConfig = ''
    SystemMaxUse=200M
    RuntimeMaxUse=50M
  '';

  # documentation/manual enabled
  documentation.man.enable = true;
  documentation.nixos.enable = true;

  # fonts, some apps require these fonts
  fonts.packages = with pkgs; [
    nerd-fonts.departure-mono
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
    liberation_ttf
    dejavu_fonts
  ];
  
  # default system-wide font
  fonts.fontconfig.defaultFonts = {
    serif = [ "DepartureMono Nerd Font Propo" ];
    sansSerif = [ "DepartureMono Nerd Font Propo" ];
    monospace = [ "DepartureMono Nerd Font Mono" ];
  };
}
