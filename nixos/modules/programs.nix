{ config, pkgs, pkgs-unstable, spicetify-nix, ... }:

let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.system};

  discord-scroll = pkgs.symlinkJoin {
    name = "discord-scroll";
    paths = [
      (pkgs.discord.override {
        withVencord = true;
      })
    ];

    buildInputs = [
      pkgs.makeWrapper
    ];

    postBuild = ''
      wrapProgram $out/bin/Discord \
        --add-flags "--enable-blink-features=MiddleClickAutoscroll"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    tree-sitter
    libayatana-appindicator

    (pkgs.sc-controller.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [
        pkgs.libayatana-appindicator
      ];
    }))

    baobab
    p7zip
    unrar
    xarchiver
    gammastep
    gnome-keyring
    linuxPackages.cpupower
    sysstat
    amdgpu_top
    ryzenadj
    delta
    dust
    duf
    libstrangle
    procs
    jq
    tokei
    chezmoi
    gcc
    gnumake
    fzf
    stylua
    shfmt
    shellcheck
    xdg-utils
    firefox
    neovim
    git
    curl
    wget
    pciutils
    usbutils
    file
    unzip
    zip
    btop
    tree
    ripgrep
    fd
    bat
    fastfetch
    kitty
    eza
    zinit
    starship
    vulkan-loader
    vulkan-tools
    lm_sensors
    zoxide
    thunar
    yazi
    cliphist
    alsa-utils
    xdg-user-dirs
    polkit_gnome
    ffmpegthumbnailer
    ntfs3g
    gnome-themes-extra
    nerd-fonts.departure-mono
    easyeffects
    pavucontrol
    lazygit
    gh
    vscode
    obsidian
    evtest
    glib
    gsettings-desktop-schemas
    motrix
    qbittorrent
    discord-scroll
    pulseaudio
  ];

  # OBS
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;

    plugins = with pkgs.obs-studio-plugins; [
      obs-vaapi
      obs-pipewire-audio-capture
    ];
  };

  # direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Thunar
  programs.thunar.enable = true;

  programs.thunar.plugins = with pkgs; [
    thunar-volman
    thunar-archive-plugin
  ];

  # Spicetify
  programs.spicetify = {
    enable = true;

    enabledExtensions = with spicePkgs.extensions; [
      # extensions here
    ];

    enabledCustomApps = with spicePkgs.apps; [
      marketplace
    ];

    theme = {
      name = "blackout";

      src = pkgs.fetchFromGitHub {
        owner = "thefoodiee";
        repo = "blackout";
        rev = "main";
        hash = "sha256-/kB4cknOWeFE1mPZVQpmB2y/RGY/JjU61KXD+lWXDzg=";
      };

      injectCss = true;
      injectThemeJs = true;
      replaceColors = true;
      sidebarConfig = true;
      homeConfig = true;
    };
  };

  # Default applications
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";

    "image/png" = "imv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/gif" = "imv.desktop";
    "image/webp" = "imv.desktop";
    "image/bmp" = "imv.desktop";
    "image/tiff" = "imv.desktop";

    "video/mp4" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
    "video/quicktime" = "mpv.desktop";

    "audio/mpeg" = "mpv.desktop";
    "audio/flac" = "mpv.desktop";
    "audio/ogg" = "mpv.desktop";

    "inode/directory" = "thunar.desktop";
  };
}
