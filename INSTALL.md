# Void Linux + dwl install checklist: desktop (`void-desktop`)

Setting up the new PC with the same Void + dwl setup as the laptop (`void`). Section 0 is done on the laptop;
everything after it is on the desktop.

Hardware: Ryzen 7 7800X3D, Gigabyte B850 EAGLE WIFI7 ICE, 32 GB DDR5-6000 CL30, XFX Swift RX 9070 16 GB,
Asus ROG Strix OLED XG27ACDNG (2560x1440 @ 360 Hz), ADATA 512 GB NVMe (system), WD Green 1 TB SATA SSD (games).

(look at `.chezmoiignore` to see what the desktop skips)

Repos:
- dotfiles: `github.com/bradleycross07/dot_files` (public; branch `void-linux`)
- dwl: `github.com/bradleycross07/void-dwl-config` (private; upstream is Codeberg dwl)

---

## 0. Before starting (on the laptop)

Do these first, then keep this checklist open on the laptop while installing on the PC.

Last updated: 18 Oct 2026.

### Right before the install
- [ ] refresh the lists, pull in any config changes made since, and push:
  ```sh
  xbps-query -m > ~/.config/system-configs/packages-void.txt
  ls /var/service > ~/.config/system-configs/services-void.txt
  chezmoi re-add
  chezmoi git -- add -A
  chezmoi git -- status
  chezmoi git -- commit -m "Refresh before desktop install" && chezmoi git -- push
  ```
- [ ] dwl: bring the `desktop` branch up to date with everything merged into `main` since it was created
  (e.g. `cursorsize`), then push it - step 4 clones it fresh:
  ```sh
  cd ~/.local/src/dwl
  # switch to it, or create it the first time
  git switch desktop 2>/dev/null || git switch -c desktop
  git merge main
  git push -u origin desktop
  # back to main, or the laptop's next `make` builds the desktop config
  git switch main
  ```
- [ ] export the settings that aren't in the dotfiles or Firefox Sync onto the Ventoy USB (next to the SSH key,
  saves and spotatui credentials - step 4):
  - uBlock Origin: Settings → **Back up to file** (filter lists, `no-cosmetic-filtering` rules, settings)
  - Vencord: Vesktop → Settings → **Backup & Restore** → export
  - put both files in a `backups/` folder on the USB

### Backing up the old Windows drives (from the live environment, to avoid Windows altogether)
The plan: free space on the SATA SSD (delete the Games folder), copy what's needed from the NVMe onto it,
install Void on the NVMe, sort the backup out from the finished PC, and only then format the SATA SSD at the very end.

1. Boot the Void live ISO on the new PC and log in as `root`
2. Find the partitions: `lsblk -f` or `fdisk -l` (the big NTFS partition on each drive). The names below are
   examples - the SATA SSD and the Ventoy USB are both `sdX` drives and either can be `sda`, so check the sizes
   before mounting anything.
3. Mount both:
   ```sh
   # an older ISO's xbps must be updated before anything else installs
   xbps-install -Su xbps
   mkdir -p /mnt/win /mnt/sata
   # Windows drive, read-only: copying FROM it still works
   mount -t ntfs3 -o ro /dev/nvme0n1pX /mnt/win
   # SATA SSD, read-write
   mount -t ntfs3 /dev/sdXN /mnt/sata
   ```
   Fast Startup is off, so both should mount. Only if the SATA mount refuses with a "dirty" volume error
   (Windows wasn't shut down cleanly - a crash, power cut or forced restart), clear the flag and retry:
   `xbps-install -S ntfs-3g && ntfsfix -d /dev/sdXN`
4. Delete the games from `/mnt/sata` to make room if needed
5. Copy what's wanted from the Windows drive (`--preserve=timestamps` instead of `-a`, since NTFS can't store
   Unix owners/permissions), e.g.
   ```sh
   mkdir -p /mnt/sata/backup
   # Windows user is "Bradley"
   cp -r --preserve=timestamps /mnt/win/Users/Bradley/Documents /mnt/sata/backup/
   # Year 1 Vivado projects
   cp -r --preserve=timestamps /mnt/win/Xilinx /mnt/sata/backup/
   ```
   Also worth a look: `Pictures`, `Desktop` and `Downloads`
6. `umount /mnt/win /mnt/sata` - then carry on with section 1, which wipes only the NVMe.
   **Don't wipe the SATA SSD** - it holds the backup until section 11.

### Disk layout
- NVMe: EFI 512 MiB FAT32 mounted at `/boot` (Limine reads the kernel from it)
  - ext4 root, no swap
- SATA SSD: ext4, games (`~/Games`), formatted only after the backup is safe
  (until then Linux reads/writes its NTFS fine via the kernel ntfs3 driver)

### BIOS / UEFI
- [ ] update the BIOS first (newest for the B850 board) - do everything below *after* the update,
  since updating resets the settings
- [ ] UEFI only: CSM off, Secure Boot off, TPM off
- [ ] disable the 7800X3D's integrated graphics (Integrated Graphics: Disabled) - the RX 9070 is the only GPU,
  so dwl can't end up compositing on the iGPU, and gamemode's `gpu_device` is unambiguous
- [ ] EXPO on for the DDR5-6000 CL30 kit - the first boot can sit on a black screen for a few
  minutes while the RAM trains
- [ ] Resizable BAR (and Above 4G Decoding) on for the RX 9070

## 1. Base install

Manual chroot install following https://docs.voidlinux.org (glibc, x86_64).

In order: partition and mount, set the xbps pins, install `base-minimal` plus the extras below, then chroot.

### Partition and mount (NVMe)

**1. Check you have the right drive.** The NVMe is the ~512 GB ADATA (`nvme0n1`); the SATA SSD (backup) and
the Ventoy USB are `sdX` drives - leave those alone. Nothing on the NVMe may be mounted:

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
umount /mnt/win 2>/dev/null
```

**2. Wipe it.** Removes the Windows partitions' signatures and then the partition table itself:

```sh
wipefs -a /dev/nvme0n1p*
wipefs -a /dev/nvme0n1
```

**3. Partition it** with `fdisk /dev/nvme0n1` - a GPT table, a 512 MiB EFI partition first (the
`efibootmgr --part 1` line later relies on it being partition 1), and the rest as one Linux partition:

| Type | What it does |
| ---- | ------------ |
| `g` | new empty GPT partition table |
| `n`, Enter, Enter, `+512M` | partition 1: default number and start, 512 MiB |
| `t`, `1` | set partition 1's type to EFI System |
| `n`, Enter, Enter, Enter | partition 2: default number, start and end (the rest of the drive) |
| `p` | print the table to check it |
| `w` | write the table and exit |

Check the result with `lsblk /dev/nvme0n1`.

**4. Format and mount:**

```sh
mkfs.vfat -F32 -n EFI /dev/nvme0n1p1
mkfs.ext4 -L void /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

**5. Remove the leftover Windows boot entry.** The wipe removed Windows Boot Manager's files, but the firmware
keeps its menu entry:

```sh
xbps-install -S efibootmgr
# list entries
efibootmgr
# delete one by its number (e.g. Boot0001 "Windows Boot Manager")
efibootmgr -b 0001 -B
```

### xbps pins: do this in the live environment, BEFORE installing anything

With the new root mounted at `/mnt`:

```sh
mkdir -p /mnt/etc/xbps.d
printf 'ignorepkg=linux\nignorepkg=linux-headers\n' > /mnt/etc/xbps.d/mainline.conf
printf 'ignorepkg=linux-firmware-nvidia\nignorepkg=linux-firmware-intel\n' \
    > /mnt/etc/xbps.d/ignore.conf
```

(`mainline.conf`: `linux-mainline` replaces the plain `linux` kernel. `ignore.conf`: Intel and NVIDIA
firmware are ignored, as this is an AMD-only system (GPU and CPU); `linux-firmware-network` covers the rest.)

### Install the base system

Copy the live system's xbps signing keys first, so the new root trusts the repo, then install:

```sh
mkdir -p /mnt/var/db/xbps/keys && cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal linux-mainline dracut eudev kmod \
    e2fsprogs kbd ncurses iproute2 iputils \
    dhcpcd dbus opendoas zsh openssh less pciutils usbutils file acpid \
    linux-firmware-amd linux-firmware-network dosfstools seatd
```

Before chrooting:
```sh
# xgenfstab + xchroot (the live ISO usually has them already)
xbps-install -S xtools-minimal
# then check it inside the chroot (below)
xgenfstab -U /mnt > /mnt/etc/fstab
# DNS, so xbps-install works inside the chroot
cp /etc/resolv.conf /mnt/etc/
# bash is there as a dracut dependency
xchroot /mnt /bin/bash
```

Once inside the chroot, confirm:

```sh
xbps-query linux >/dev/null \
    && echo "plain linux IS installed - remove it" || echo "ok: no plain linux"

xbps-query -l | command grep 'linux-mainline\|^ii linux[0-9]'

xbps-query runit-void >/dev/null && echo "ok: runit-void installed"
```

### Inside the chroot

- [ ] check `/etc/fstab` (generated above): ext4 root with `noatime`, EFI on `/boot`, and add `/tmp` as tmpfs:
  `tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0`
- [ ] set the hostname - chezmoi relies on it: `echo void-desktop > /etc/hostname`
- [ ] and resolve it locally, as on the laptop (`127.0.1.1 void`): `echo '127.0.1.1 void-desktop' >> /etc/hosts`
- [ ] timezone: `ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime`
- [ ] locale (glibc): uncomment `en_GB.UTF-8 UTF-8` in `/etc/default/libc-locales`, set `LANG=en_GB.UTF-8` in
  `/etc/locale.conf` (`glibc-locales` comes with `base-minimal`; `xbps-reconfigure -fa` at the end generates it)
- [ ] root password, as a way back in if `doas.conf` ever breaks: `passwd`
- [ ] user `bradley` with shell `zsh` and a password (the `_seatd` group exists because seatd was installed above;
  `gamemode` is added later, once the package exists - section 11):
  ```sh
  useradd -m -s /bin/zsh -G wheel,users,audio,video,input,plugdev,_seatd bradley
  passwd bradley
  ```
- [ ] `opendoas` instead of sudo - give it a minimal config so `doas` works on first boot
  (the full one is restored in step 10), and check it before relying on it:
  ```sh
  echo 'permit persist bradley as root' > /etc/doas.conf && chmod 0400 /etc/doas.conf
  doas -C /etc/doas.conf && echo "doas.conf ok"
  ```

Still in the chroot, enable networking so the first boot is online (in a chroot, services are enabled
in `/etc/runit/runsvdir/default/`, not `/var/service/`):

```sh
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default/
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
# usually already enabled by runit-void; -f avoids "File exists"
ln -sf /etc/sv/udevd /etc/runit/runsvdir/default/
```

### Bootloader: Limine

Limine only reads FAT, so the kernels and initramfs live on the EFI partition itself, mounted at `/boot`.
Each kernel + initramfs is tens of MB; 512 MiB is plenty if old kernels are cleaned up (`doas vkpurge rm all`).

Inside the chroot:

```sh
xbps-install -S limine efibootmgr
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
efibootmgr --create --disk /dev/nvme0n1 --part 1 \
    --label "Void Linux" --loader '\EFI\BOOT\BOOTX64.EFI'
```

Copy `BOOTX64.EFI` again whenever the `limine` package updates.

Kernel hook: Void's `limine` package doesn't update `limine.conf` and Limine has no wildcards, so this rewrites
it after every kernel install (the new kernel first, the previous one as a fallback entry). Fetch it from the
dotfiles (added in step 0):

```sh
mkdir -p /etc/kernel.d/post-install && cd /etc/kernel.d/post-install
xbps-uhelper fetch https://raw.githubusercontent.com/bradleycross07/dot_files/void-linux/dot_config/system-configs/executable_60-limine
mv executable_60-limine 60-limine && chmod +x 60-limine
cat 60-limine
```

### Finish the chroot

Configure every package (this also generates the locale and the initramfs), then write `limine.conf` for the
installed kernel - from `/`, since the hook uses relative paths:

```sh
xbps-reconfigure -fa
cd /
latest=$(ls /boot | sed -n 's/^vmlinuz-//p' | sort -V | tail -1)
/etc/kernel.d/post-install/60-limine linux-mainline "$latest"
cat /boot/limine.conf
# vmlinuz-<version> and initramfs-<version>.img must both be there
ls /boot
```

### Leave the chroot and reboot

```sh
# leave the chroot
exit
umount -R /mnt
# pull the Ventoy USB out once the screen goes blank
reboot
```

## 2. Repositories and packages

Log in as `bradley` on tty1 (dhcpcd from step 1 should already have you online - check with `ping -c 3 voidlinux.org`).
zsh shows its first-run menu because there's no `~/.zshrc` yet - press `q` to skip it.

The dotfiles are cloned now but applied in step 6: the package lists, mirrors and patches are read straight from
the clone, and the repo is public, so no SSH key is needed for this:

```sh
# delta is .gitconfig's pager
doas xbps-install -S void-repo-nonfree git chezmoi delta
chezmoi init --branch void-linux https://github.com/bradleycross07/dot_files.git
# git identity + commit signing, used by the patches in step 4
chezmoi apply ~/.gitconfig
# the laptop's mirrors, for main and nonfree (written by xmirror on the laptop)
cd "$(chezmoi source-path)/dot_config/system-configs"
doas cp xbps.d/00-repository-main.conf xbps.d/10-repository-nonfree.conf /etc/xbps.d/
doas xbps-install -Su
```

Install packages by hand, one group at a time - the laptop's list (`packages-void.txt`, in the same folder) is a
reference to pick from, not something to install wholesale. Build dependencies are installed with each build in step 4.

Don't install on the desktop:
- laptop power/memory/network: `tlp`, `zramen`, `earlyoom`, `iwd`, `wifi-firmware`, `unbound`, `wireguard-tools`
- `grub-x86_64-efi` (Limine instead), `elogind` (seatd + turnstile instead), `cronie`, `socklog-void`, `yarn`
- laptop session extras (autostart.sh doesn't run them on the desktop): `kanshi`, `wlr-randr`, `gammastep`,
  `xsettingsd`, `polkit-gnome`, `gnome-keyring`, `cliphist`, `sway-audio-idle-inhibit`
  - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
  - add `gnome-keyring` back if signing into apps that need a keyring
- laptop-only apps: VS Code, ProjectLibre, Vivado, Spotify + Spicetify, and the restricted `discord` package
  (Vesktop instead)

Packages the later steps rely on (still in the `system-configs` folder, for the font lists):

```sh
doas xbps-install -S chrony nftables rtkit turnstile power-profiles-daemon
doas xbps-install -S pipewire wireplumber alsa-pipewire easyeffects pavucontrol \
    swayidle waylock wlopm wl-clipboard foot fuzzel qt6-wayland
doas xbps-install -S mesa-dri mesa-vulkan-radeon vulkan-loader
doas xbps-install -S mesa-vaapi libva-utils
doas xbps-install -S gamemode gamescope mangohud
doas xbps-install -S $(cat fonts-void.txt)
[ -s fonts-confd.txt ] && while read -r c; do
    doas ln -sf "/usr/share/fontconfig/conf.avail/$c" /etc/fonts/conf.d/
done < fonts-confd.txt
doas xbps-install -S curl jq
doas xbps-install -S xdg-utils desktop-file-utils
doas xbps-install -S firefox
cd
```

## 3. Shell and editor

```sh
doas xbps-install -S starship zoxide fzf eza bat ripgrep dust duf procs fastfetch neovim
git clone https://github.com/zdharma-continuum/zinit.git ~/.local/share/zinit/zinit.git
# Neovim's treesitter parsers need the CLI; rust, cargo and mold are also used by the builds in step 4
doas xbps-install -S rust cargo mold
cargo install tree-sitter-cli
```

`.zshrc` (which aliases `grep` to `rg`, `cat` to `bat` and so on) and the Neovim config arrive in step 6;
lazy.nvim bootstraps itself on Neovim's first launch after that.

## 4. Built from source (`~/.local/src`)

### From the Ventoy USB: SSH key, game saves, spotatui credentials

The SSH key comes first: dwl is a private repo, and the patches below are signed commits.

```sh
doas mount -o uid=1000,gid=1000 /dev/sdX1 /mnt
# SSH key for GitHub auth + signing (same filename, so .gitconfig works unchanged)
mkdir -p ~/.ssh
cp /mnt/ssh-key/{github-void,github-void.pub,config} ~/.ssh/
chmod 700 ~/.ssh && chmod 600 ~/.ssh/github-void ~/.ssh/config
ssh -T git@github.com
# game saves, before those games are first launched (tar because exFAT can't store symlinks)
# Hollow Knight + Silksong (keeps Silksong's own `default` -> account-id link)
tar -xzf /mnt/saves/unity3d.tar.gz -C ~
# Celeste: on the laptop `Saves` linked into the game's install folder; here it's a normal folder
tar -xzf /mnt/saves/celeste.tar.gz -C ~
# spotatui's Spotify app credentials (not in the public repo)
mkdir -p ~/.config/spotatui && cp /mnt/spotatui/client.yml ~/.config/spotatui/
# uBlock Origin + Vencord backups (exported in step 0), restored from Firefox/Vesktop in step 7
mkdir -p ~/backups && cp /mnt/backups/* ~/backups/
# once ssh -T has greeted you: the key and credentials don't stay on the USB
rm -r /mnt/ssh-key /mnt/spotatui
doas umount /mnt
```

### Rust builds

Rust builds use mold and native CPU tuning from the command line (not `~/.cargo/config.toml`). The binaries go in
`~/.local/bin`, which `.zprofile` puts on `PATH` from step 6:

```sh
mkdir -p ~/.local/bin
```

### dwl
```sh
doas xbps-install -S base-devel pkg-config wlroots0.20-devel \
    wayland-devel wayland-protocols \
    libinput-devel libxkbcommon-devel xcb-util-wm-devel xorg-server-xwayland
git clone git@github.com:bradleycross07/void-dwl-config.git ~/.local/src/dwl
cd ~/.local/src/dwl
git remote add upstream https://codeberg.org/dwl/dwl.git
# merged with main and pushed in step 0
git checkout desktop
make && doas make install
```
(`base-devel` is gcc + make; `xcb-util-wm-devel` provides `xcb-icccm` for the XWayland build;
`xorg-server-xwayland` runs X11 apps and the few games that still need it - if `make` reports another missing
pkg-config module, install its `-devel` package)
- the `desktop` branch: monitor rule, no brightness keys, no Mod+v clipboard picker
- dwl runs `~/.local/bin/autostart.sh` at startup (a template): PipeWire, EasyEffects (mic for Vesktop) and swayidle
  (lock after 10 min, screen off after 15 - protects the OLED)
- quitting dwl stops everything autostart.sh started (the autostart patch kills its process group)
- first started in step 7, once seatd and turnstile are running

### Native Wayland by default

Most toolkits already pick Wayland when it's there: GTK 3/4 (Firefox, pavucontrol, EasyEffects), SDL3 and foot.
The rest is handled by `.zprofile` (from the dotfiles), which is exported before dwl starts:

```sh
# Qt apps, X11 as fallback (needs qt6-wayland - step 2)
export QT_QPA_PLATFORM="wayland;xcb"
# SDL2 apps: Wayland first, X11 as fallback
export SDL_VIDEODRIVER=wayland,x11
# Electron apps: Vesktop, Obsidian, Motrix
export ELECTRON_OZONE_PLATFORM_HINT=auto
```

- `SDL_VIDEODRIVER`: SDL2 still prefers X11 by default, so this is what keeps SDL2 apps native. The fallback list
  only works in SDL 2.0.22+ - a game bundling an older SDL2 can fail to open a window. If that happens, override it
  for that game only (e.g. `SDL_VIDEODRIVER=x11` in its Aurelia launch script)
- `ELECTRON_OZONE_PLATFORM_HINT`: newer Electron versions pick Wayland on their own and ignore it, so it's harmless

Check what's still on XWayland with `xlsclients` (from the `xlsclients` package) while things are running -
anything it lists is an X11 client.

Hollow Knight and Silksong (native Linux builds via Aurelia) already run on Wayland. Keep XWayland built into dwl
anyway for the few Wine/Proton games that still need X11 - it costs nothing when nothing's using it. For those,
Wine's Wayland driver is the way to try native Wayland first: `PROTON_ENABLE_WAYLAND=1` on GE-Proton, or for
plain Wine, unset `DISPLAY` for that game so Wine picks its Wayland driver. Not every game works with it yet,
so treat it as per-game.

### Aurelia
- needs `rust cargo mold` (and possibly `openssl-devel` - it's on the laptop's list)
- the launch scripts run each game inside `bwrap --unshare-net` (its own network namespace, so the game never
  hears about USB hotplugs - stops the Unity freeze when a controller/mouse is plugged in). Flatpak pulls
  bubblewrap in too, but install it explicitly so the scripts don't depend on Flatpak:
  ```sh
  doas xbps-install -S bubblewrap
  ```
- 32-bit graphics libraries for Wine/Proton games (older 32-bit games need them):
  ```sh
  doas xbps-install -S void-repo-multilib
  doas xbps-install -S mesa-dri-32bit vulkan-loader-32bit mesa-vulkan-radeon-32bit
  ```
- clone it, then restore the local tweaks from the dotfiles repo onto a `local` branch
  (if `git am` stops on a conflict because upstream changed, fix the file, `git add` it, then `git am --continue`):
  ```sh
  git clone https://github.com/Drackrath/Aurelia.git ~/.local/src/Aurelia
  cd ~/.local/src/Aurelia
  git checkout -b local
  git am "$(chezmoi source-path)"/patches/aurelia/*.patch
  ```
- build for the fastest binary (tuned for this CPU, linked with mold), install, then clean:
  ```sh
  RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold" cargo build --release
  cp target/release/aurelia ~/.local/bin/
  cargo clean
  ```
  (release builds already use full optimisation; `target-cpu=native` tunes for the machine it's built on, so
  the desktop builds its own binary). `update-aurelia` from the dotfiles handles later updates.
- game library: `~/Games/Aurelia` - don't install games until the SATA SSD is formatted and mounted on `~/Games`
  (end of section 11); anything installed there before would end up on the NVMe, hidden under the mount.
  Aurelia's `config.json` isn't in the dotfiles, so set the library path to `~/Games/Aurelia` on first run
- launch scripts (`~/.config/Aurelia/scripts/<appid>.sh`) come with the dotfiles; adjust them for this
  monitor in section 11. Any script with a hard-coded game path (HuniePop's defaults to
  `~/.local/share/Steam/steamapps/common`, the laptop's library) needs pointing at `~/Games/Aurelia` instead:
  ```sh
  rg -n 'local/share/Steam' ~/.config/Aurelia/scripts/
  ```

### OpenRazer (mouse DPI and polling rate)
- install the driver, daemon and GUI, and join the `plugdev` group (log out and back in afterwards):
  ```sh
  doas xbps-install -S openrazer-meta razergenie
  doas usermod -aG plugdev bradley
  ```
- the driver is a DKMS module, so the headers for the running kernel must be installed or it won't build
- the daemon runs as your user, not as a runit service: start it the same way as on the laptop
- set DPI and polling rate in RazerGenie; the daemon remembers them

### spotatui
- needs `rust cargo mold` plus the build dependencies from its README (the laptop's package list has them)
- clone, restore the local patches, build:
  ```sh
  git clone https://github.com/LargeModGames/spotatui.git ~/.local/src/spotatui
  cd ~/.local/src/spotatui
  git checkout -b local
  git am "$(chezmoi source-path)"/patches/spotatui/*.patch
  RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold" cargo build --release
  cp target/release/spotatui ~/.local/bin/
  cargo clean
  ```
- zsh completion: `_spotatui` comes with the dotfiles in `~/.local/share/zsh/site-functions`, which `.zshrc`
  adds to `fpath`

### Vesktop
- needs pnpm (standalone installer) and Node.js, which on the laptop is managed by pnpm itself
  (`pnpm ls -g` shows `node@26` as a global) rather than Void's `nodejs` package:
  ```sh
  # writes a pnpm block to ~/.zshrc - step 6 replaces that file with
  # the dotfiles' .zshrc, which has the same block
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  # reload so PNPM_HOME/PATH apply
  exec zsh
  pnpm --version
  # pnpm-managed Node, same major version as the laptop
  # (see `pnpm help env` if the command has changed)
  pnpm env use --global 26
  node --version
  ```
- clone, restore the raised-bitrate patch, build, install into `~/.local/opt/Vesktop`:
  ```sh
  git clone https://github.com/Vencord/Vesktop.git ~/.local/src/Vesktop
  cd ~/.local/src/Vesktop
  git checkout -b local
  git am "$(chezmoi source-path)"/patches/vesktop/*.patch
  pnpm install --frozen-lockfile
  # unpacked build in dist/linux-unpacked
  pnpm package:dir
  rm -rf ~/.local/opt/Vesktop
  mkdir -p ~/.local/opt
  cp -r dist/linux-unpacked ~/.local/opt/Vesktop
  ```
- `~/.local/bin/vesktop` (wrapper) and `~/.local/share/applications/Vesktop.desktop` come with the dotfiles;
  the desktop entry's `MimeType=x-scheme-handler/discord;` plus `mimeapps.list`'s
  `x-scheme-handler/discord=Vesktop.desktop` make it open `discord://` links (database refreshed in step 6)

### InputPlumber
- build dependencies. `clang` alone isn't enough: bindgen looks for the unversioned `libclang.so`, which only
  the matching `clang<N>-devel` package provides (it was `clang21-devel` on the laptop - check the number with
  `xbps-query clang` / `xbps-query -Rs clang` first):
  ```sh
  doas xbps-install -S rust cargo clang clang21-devel pkg-config eudev-libudev-devel libiio-devel
  ```
- clone, build as your user, install as root (building with doas would make cargo run as root):
  ```sh
  git clone https://github.com/ShadowBlip/InputPlumber.git ~/.local/src/InputPlumber
  cd ~/.local/src/InputPlumber
  make build
  doas make install PREFIX=/usr
  # the install also drops systemd units, which do nothing on Void
  doas rm /usr/lib/systemd/system/inputplumber*.service
  ```
  (if the build ever stops on `couldn't find any valid shared libraries matching: ['libclang.so'...]`, the
  `clang<N>-devel` version doesn't match - `find /usr/lib -name 'libclang*.so*'` shows which one is installed)
- its install adds udev rules, hwdb entries and a D-Bus system policy, which only take effect once reloaded:
  ```sh
  doas udevadm hwdb --update && doas udevadm control --reload && doas udevadm trigger
  # picks up org.shadowblip.InputPlumber.conf, so the service may claim its name
  doas sv reload dbus
  ```
- its DualSense config and runit service come from the dotfiles - restored in step 7

### Spotify (optional - not planned)
spotatui is the Spotify client on the desktop, so neither the official app nor Spicetify is installed. If Premium
offline downloads are ever needed (only the official app does them), build it from void-packages as on the laptop:
```sh
git clone https://github.com/void-linux/void-packages.git ~/.local/src/void-packages
cd ~/.local/src/void-packages
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
./xbps-src pkg spotify && doas xbps-install -R hostdir/binpkgs/nonfree spotify
```
(Spicetify and `spotify.desktop` are in `.chezmoiignore` for the desktop - drop the `spotify.desktop` line if
installing it. `~/.spicetify` on `PATH` in `.zprofile` is harmless when it doesn't exist)

## 5. Manually installed apps (`~/.local/opt`)

Each has a small `exec` wrapper in `~/.local/bin`; the wrappers and update scripts arrive with the dotfiles in
step 6. The apps themselves are downloaded fresh into the paths below. Vesktop is built from source (step 4).

| App           | Location                         | Notes                                   |
| ------------- | -------------------------------- | --------------------------------------- |
| Obsidian      | `~/.local/opt/Obsidian`          | AppImage extracted; install/update with `update-obsidian` |
| Vesktop       | `~/.local/opt/Vesktop`           | built from `~/.local/src/Vesktop` (step 4) |
| Motrix        | `~/.local/opt/Motrix`            | AppImage extracted; wrapper runs `AppRun` |
| Archipelago   | `~/.local/opt/Archipelago`       | wrapper runs `ArchipelagoLauncher`      |
| Lumafly       | `~/.local/opt/Lumafly`           | wrapper `cd`s into the folder first     |

Obsidian - `update-obsidian` isn't on `PATH` yet, so run it from the dotfiles clone:

```sh
sh "$(chezmoi source-path)/dot_local/bin/executable_update-obsidian"
```

`discord-rpc-wrap` (used by the Aurelia launch scripts to show games in Discord) runs from its own Python venv:

```sh
doas xbps-install -S python3
python3 -m venv ~/.local/share/discord-rpc-venv
~/.local/share/discord-rpc-venv/bin/pip install pypresence
```

### Flatpak (user installation)

One app comes from Flathub, installed per-user. The flatpak export paths are added to `XDG_DATA_DIRS` by
`/etc/profile.d/flatpak.sh`, which the package installs, so the app shows up in fuzzel after the next login.

```sh
doas xbps-install -S flatpak
flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub cz.viceverse.serein
```

## 6. Dotfiles (chezmoi)

```sh
# the laptop-only files must show up here - if the list only has README.md, INSTALL.md and patches,
# the hostname isn't `void-desktop` and the laptop's TLP/kanshi/Vivado files would be applied
chezmoi ignored
chezmoi diff
chezmoi apply
```

`chezmoi apply` asks about `~/.zshrc`, since pnpm's installer wrote one in step 4 - overwrite it.

- [ ] log out and back in on tty1 - `.zprofile` is only read at login, and it sets `PATH` (`~/.local/bin`,
  `~/.cargo/bin`), the Wayland/Qt/SDL/Electron variables and the cursor settings
- [ ] fonts: `~/.config/fontconfig` and `~/.local/share/fonts` are in place now, so rebuild the cache and check
  the defaults match the laptop:
  ```sh
  fc-cache -f
  for f in monospace sans-serif serif emoji; do printf '%-11s ' "$f"; fc-match "$f"; done
  # monospace = DepartureMono Nerd Font Mono, sans-serif = DepartureMono Nerd Font Mono,
  # serif = Noto Serif, emoji = Noto Color Emoji
  ```
- [ ] desktop entries: `update-desktop-database ~/.local/share/applications`
- [ ] `doas xbps-install -S github-cli` then `gh auth login` (token stays local, never commit `~/.config/gh`)
- [ ] switch the chezmoi remote to SSH to push from this machine:
  `chezmoi git -- remote set-url origin git@github.com:bradleycross07/dot_files.git`

## 7. Services (runit)

```sh
# dbus, dhcpcd and udevd were already enabled in step 1
# seatd + turnstile instead of elogind, power-profiles-daemon for the CPU,
# acpid for the power button (no elogind to handle it)
for s in chronyd nftables rtkit seatd turnstiled power-profiles-daemon acpid; do
  doas ln -s /etc/sv/$s /var/service/
done
# once runit has started it (a few seconds) - remembered across reboots:
doas powerprofilesctl set performance
```

InputPlumber (built in step 4): restore its DualSense config (`persist: true`, so the virtual Xbox pad survives
a replug) and its service, then enable it. The log service writes its own log with svlogd to
`/var/log/inputplumber`, so it works without socklog - keep it. Check it's that version first:

```sh
# should be: exec svlogd -tt /var/log/inputplumber  (not vlogger)
cat ~/.config/system-configs/sv-inputplumber/log/run
doas mkdir -p /etc/inputplumber/devices.d
doas cp ~/.config/system-configs/inputplumber/*.yaml /etc/inputplumber/devices.d/
doas cp -r ~/.config/system-configs/sv-inputplumber /etc/sv/inputplumber
doas ln -s /etc/sv/inputplumber /var/service/
# with the DualSense plugged in: it should be detected and blocked, with a virtual Xbox 360 pad created
doas tail /var/log/inputplumber/current
```

- [ ] log out and back in on tty1, then check `echo $XDG_RUNTIME_DIR` prints `/run/user/1000` -
  dwl, PipeWire, foot and the portals all need it. Void's turnstile manages the rundir by default and its PAM
  hook is already in `/etc/pam.d/system-login`, so it should just work. If it's empty, check `manage_rundir`
  isn't set to `no` in `/etc/turnstile/turnstiled.conf`, that `pam_turnstile.so` is still in `system-login`, and
  that `turnstiled` is running (`doas sv status turnstiled`)
- [ ] only keep `agetty-tty1` and `agetty-tty2`: `doas rm /var/service/agetty-tty{3,4,5,6}`
- [ ] irqbalance, bluetoothd, NetworkManager, wpa_supplicant: leave disabled

### First dwl session

- [ ] start it by typing `dwl` on tty1 (a function in `.zshrc`)
- [ ] Firefox: sign in to Firefox Sync (bookmarks, passwords, history, extensions) instead of copying the profile
- [ ] Firefox `user.js` (Betterfox + overrides), `userChrome.css` and `userContent.css` - not applied by chezmoi
  on the desktop, since the profile folder is named per install. Start Firefox once, open `about:profiles`
  and note the **Root Directory** of the profile in use (on the laptop it ended in `.default-default`, not
  `.default-release`), close Firefox completely, then copy all three:
  ```sh
  # paste the Root Directory from about:profiles
  p=~/.config/mozilla/firefox/XXXXXXXX.default-default
  src=$(echo "$(chezmoi source-path)"/dot_config/private_mozilla/private_firefox/*)
  mkdir -p "$p/chrome"
  cp "$src"/user.js "$p/"
  cp "$src"/chrome/userChrome.css "$src"/chrome/userContent.css "$p/chrome/"
  ```
  - `user.js` already turns on `toolkit.legacyUserProfileCustomizations.stylesheets`, so there's nothing to
    set in `about:config`
  - edit `user.js` for the desktop **before** the next start: delete `user_pref("media.av1.enabled", false);` -
    that's only for the laptop's GPU, the RX 9070 decodes AV1 in hardware
  - the `chrome` CSS is only read at startup: make sure `pgrep -a firefox` shows nothing before starting it
  - check in `about:config`: `browser.contentblocking.category` = `standard`, `media.av1.enabled` = `true`
  - `userChrome.css` hides the tab bar, so install Sidebery (via Sync) before relying on it
- [ ] uBlock Origin: Settings → **Restore from file** → the backup in `~/backups` (the settings aren't in Sync)
- [ ] Vesktop: log in to Discord. Neither the session nor the Vencord settings are in the dotfiles - import them
  from `~/backups` (Settings → Backup & Restore, exported on the laptop in step 0)

## 8. Audio

Already handled by the dotfiles:
- `~/.config/pipewire/pipewire.conf.d/` - rates + symlinks that make PipeWire launch WirePlumber and pipewire-pulse
- EasyEffects mic chain: `~/.config/easyeffects/db/` (gate, compressor, rnnoise)

Manual:
- [ ] route ALSA through PipeWire, so apps and games that only talk ALSA play through PipeWire instead of
  grabbing the sound card directly ("Device default ... Busy"); needs `alsa-pipewire`:
  ```sh
  doas mkdir -p /etc/alsa/conf.d
  doas ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
  doas ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
  ```
- [ ] pick default devices (headset sink, `easyeffects_source` as mic) - pavucontrol, or
  `wpctl status` to find the IDs and `wpctl set-default <id>`
- [ ] EasyEffects is for the mic only: Preferences → Audio → "Process all output streams" **off**,
  "Process all input streams" on (saved in `easyeffects/db/`, so this should already be set). Apps then play
  straight to the headset instead of through `easyeffects_sink`
- [ ] Vesktop → Settings → Voice & Video: Output Device **Default** (not Easy Effects Sink), Input Device
  Default or Easy Effects Source. When streaming, the picker's audio settings: Ignore Inputs, Ignore Virtual
  and Ignore Devices on, Device Selection and Microphone Workaround off
- [ ] stream audio needs `venmic-fix` (from the dotfiles) after starting each stream: venmic captures each app
  through a loopback whose target WirePlumber ignores, so the loopback gets your mic instead of the app -
  viewers hear you twice and none of the app. Start the stream with the app playing, then run `venmic-fix`;
  check with `pw-link -l | rg -A3 'venmic-loopback-capture'` (the app feeds it, not `easyeffects_source`).
  After a Vesktop update, test a stream without it first - if the mic is no longer in the loopback, upstream
  fixed it and the script can go

## 9. Screen sharing (Vesktop, Firefox, OBS)

On Wayland, apps can't capture the screen themselves. They ask **xdg-desktop-portal**, which hands the request to
a backend for the compositor; for wlroots compositors like dwl that's **xdg-desktop-portal-wlr**, which captures
the screen and streams it to the app through **PipeWire**. Nothing here needs a runit service: the portals are
started on demand by the D-Bus session bus that `dbus-run-session` gives dwl.

Needs: PipeWire running (autostart.sh), the D-Bus session bus, `XDG_RUNTIME_DIR` (turnstile - checked in step 7),
and `XDG_CURRENT_DESKTOP=wlroots`, which `.zprofile` already exports (dwl doesn't set it, and the portal picks its
backend from it).

```sh
doas xbps-install -S xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```
(`-gtk` provides the file-picker dialogs - also used by Qt apps, since qt6ct is set to `xdgdesktopportal` - and
the dark-mode setting; `-wlr` only does screen capture and screenshots)

- [ ] the portals find the compositor because `~/.local/bin/autostart.sh` passes the Wayland variables to the
  D-Bus session. It comes with the dotfiles, so just check the line is there, outside any per-machine block and
  before anything else (`rg -n dbus-update-activation-environment ~/.local/bin/autostart.sh`):
  ```sh
  dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
  ```
  (it's a template - add it with `chezmoi edit ~/.local/bin/autostart.sh` if it's ever missing)
- [ ] `~/.config/xdg-desktop-portal/portals.conf` (from the dotfiles) - which backend handles what:
  ```ini
  [preferred]
  default=gtk
  org.freedesktop.impl.portal.ScreenCast=wlr
  org.freedesktop.impl.portal.Screenshot=wlr
  ```
- [ ] `~/.config/xdg-desktop-portal-wlr/config` (from the dotfiles) - pick the monitor with fuzzel instead of the
  default (`slurp`, not installed):
  ```ini
  [screencast]
  max_fps=60
  chooser_type=dmenu
  chooser_cmd=fuzzel --dmenu -p "Share: "
  ```
  (`max_fps` caps the stream, not the monitor - leave it at 60, since streams can't usefully send 360 Hz anyway)
- [ ] test: restart dwl so the portals start, then start a screen share in Vesktop - fuzzel should pop up with
  the monitor name. Firefox's https://mozilla.github.io/webrtc-landing/gum_test.html (Screen capture) is a quick
  second check. If nothing appears, `pgrep -a xdg-desktop-portal` shows whether both portals started

Notes:
- whole-monitor sharing is the main use, but single windows can be shared too: dwl 0.9 exposes
  `ext_image_copy_capture_manager_v1`, `ext_foreign_toplevel_list_v1` and
  `ext_foreign_toplevel_image_capture_source_manager_v1` (confirmed on the laptop with
  `wayland-info | grep -E 'ext_image_copy|ext_foreign_toplevel'`, from `wayland-utils`). Whether windows show up
  in the fuzzel picker depends on the xdg-desktop-portal-wlr version - check with `xbps-query xdg-desktop-portal-wlr`
- Vesktop is used (built from source with a raised stream bitrate - step 4) for 1440p 60 fps streams with Nitro.
  Stream *audio* is still hit and miss on Linux

## 10. System configs (/etc)

`dhcpcd.conf` and `rc.conf` (and `~/.local/bin/autostart.sh`) are chezmoi templates (`.tmpl` in the repo):
their per-machine parts are filled in from the hostname. Edit them with `chezmoi edit` - `chezmoi re-add` skips templates.

Copies live in `~/.config/system-configs` (applied by chezmoi in step 6).

| Backup file          | Restore to                    | Notes                     |
| -------------------- | ----------------------------- | ------------------------- |
| `99-network.conf`    | `/etc/sysctl.d/`              | BBR + fq                  |
| `doas.conf`          | `/etc/doas.conf`              | check with `doas -C` first; `chmod 0400`; passwordless poweroff/reboot/zzz |
| `nftables.conf`      | `/etc/nftables.conf`          | check with `nft -c -f` first |
| `rc.conf`            | `/etc/rc.conf`                | template: KEYMAP `us`     |
| `dhcpcd.conf`        | `/etc/dhcpcd.conf`            | template: Cloudflare DNS  |
| `gamemode.ini`       | `/etc/gamemode.ini`           | set `gpu_device` for this PC (section 11) |
| `dhcpcd.exit-hook`   | `/etc/dhcpcd.exit-hook`       | sets the fq qdisc on the interface when dhcpcd binds (pairs with BBR in `99-network.conf`) |
| `99-local.rules`     | `/etc/udev/rules.d/`          | HyperX volume keys ignored by libinput. **No DualSense lines** - a `MODE="0666"` hidraw rule here would run after `71-dualsense-hide.rules` and reopen the raw controller to games |
| `71-dualsense-hide.rules` | `/etc/udev/rules.d/`     | raw DualSense nodes root-only (only InputPlumber opens them), hidden from libinput/dwl |
| `dualsense-no-audio.conf` | `/etc/modprobe.d/`       | `snd_usb_audio` refuses the DualSense's sound card - no audio-device hotplug, no game stutter on replug. Applies after a reboot |
| `99-nofile.conf`     | `/etc/security/limits.d/`     | raised open-files limit; applies at next login |
| `inputplumber/*.yaml`| `/etc/inputplumber/devices.d/`| DualSense device config - already restored in step 7 |
| `60-limine`          | `/etc/kernel.d/post-install/` | `chmod +x`; already in place from step 1 (fetched from the repo) - only for a future reinstall |
| `xbps.d/*.conf`      | `/etc/xbps.d/`                | mirrors restored in step 2. Don't restore the pins from here: `ignore.conf` is the laptop's (NVIDIA only) - the desktop's are written in step 1 |

```sh
cd ~/.config/system-configs
# check doas.conf and nftables.conf BEFORE copying them into /etc:
doas -C doas.conf && doas cp doas.conf /etc/doas.conf && doas chmod 0400 /etc/doas.conf
doas nft -c -f nftables.conf && doas cp nftables.conf /etc/nftables.conf
doas cp 99-network.conf /etc/sysctl.d/
doas cp rc.conf /etc/rc.conf          # KEYMAP already filled in by chezmoi
doas cp dhcpcd.conf /etc/dhcpcd.conf   # DNS line already filled in by chezmoi
doas cp gamemode.ini /etc/gamemode.ini # then check gpu_device (section 11)
doas cp dhcpcd.exit-hook /etc/dhcpcd.exit-hook
# 99-local.rules must not contain a DualSense (054c) line - this should print nothing:
rg -n 054c 99-local.rules
doas cp 99-local.rules 71-dualsense-hide.rules /etc/udev/rules.d/
doas udevadm control --reload && doas udevadm trigger
# takes effect at the next reboot (check then: `doas dmesg | rg 054c` says "device (054c:0ce6) is disabled")
doas cp dualsense-no-audio.conf /etc/modprobe.d/
doas cp 99-nofile.conf /etc/security/limits.d/
# apply them: the firewall, DNS + qdisc, and sysctls
doas sv restart nftables dhcpcd
doas sysctl --system
cd
```

- [ ] IPv6 is disabled on the kernel command line, so any `ip6` table in `nftables.conf` or `net.ipv6.*` key in
  `99-network.conf` will fail here: `nft -c -f` above catches the first; for the second, `doas sysctl --system`
  prints an error per missing key - harmless, but drop those keys if you want a clean run

Not backed up on purpose (machine-specific): `/etc/fstab`.

## 11. Desktop-specific

- [ ] GPU (RX 9070, RDNA4): Mesa + `mesa-vulkan-radeon` (installed in step 2), AMD firmware, mainline kernel -
  check with `lspci -k` that the GPU uses the `amdgpu` driver, and that it's the only GPU (iGPU disabled in the BIOS)
- [ ] dwl `desktop` branch: monitor rule for the XG27ACDNG, 2560x1440 @ 360 Hz
- [ ] machine-specific configs - they arrive with the laptop's values; edit them for this PC:
  - fastfetch (`~/.config/fastfetch/config.jsonc`): CPU line ("Ryzen 5 5500U" → 7800X3D), GPU line
    ("Lucienne" → RX 9070), memory speed ("4266 MT/s" → 6000)
  - btop (`~/.config/btop/btop.conf`): `custom_cpu_name`, `custom_gpu_name0`, `show_battery`
  - mpv (`~/.config/mpv/mpv.conf`): `gpu-api=vulkan`, heavier scalers, add `av1` to `hwdec-codecs`, and loosen
    `ytdl-format` - the laptop caps YouTube at VP9 because its decoder can't do AV1, the RX 9070 can
    (`vainfo` lists what the GPU decodes)
  - Vesktop wrapper (`~/.local/bin/vesktop`): hardware *encoding* is disabled
    (`--disable-features=AcceleratedVideoEncoder,VaapiVideoEncoder`). The RX 9070 encodes H.264/HEVC/AV1, so
    optionally drop that line and add `AcceleratedVideoEncoder` to `--enable-features`, then test a 1440p 60 stream;
    put the line back if streams look worse or won't start
  - so chezmoi doesn't overwrite these with the laptop's values (or `re-add` the desktop's values back to the
    laptop): template the hardware lines on `.chezmoi.hostname`, or list the files in `.chezmoiignore`
    for `void-desktop` once they're edited
- [ ] text/code files open in Neovim inside foot: `nvim-foot.desktop` and `mimeapps.list` come with the
  dotfiles, so just check: `xdg-mime query default text/plain` should print `nvim-foot.desktop`
- [ ] gaming:
  - gamemode group (exists now that the package is installed): `doas usermod -aG gamemode bradley`,
    then log out and back in and check with `id | rg gamemode`
  - `/etc/gamemode.ini` (restored in step 10): `gpu_device` must be the RX 9070's card number. With the iGPU
    disabled there should only be one - check, and fix the file if it isn't `0`:
    ```sh
    ls -l /sys/class/drm/ | rg 'card[0-9] '
    # the PCI address in the card's link should match the RX 9070
    lspci -D | rg -i 'vga|display'
    ```
  - test: `gamemoded -t` should end with "All Tests Passed!". The governor and GPU helpers go through polkit;
    on the laptop that ran with elogind, here it doesn't. If those two tests fail with authorisation errors,
    check `polkit` is installed (gamemode should pull it in) and enable it: `doas ln -s /etc/sv/polkitd /var/service/`
  - Aurelia launch scripts: `gamemoderun` goes in front of `gamescope`. Update the gamescope resolutions and
    refresh rates for this monitor (`-W 2560 -H 1440 -r 360`, frame caps via `--framerate-limit`).
    MangoHud's config comes with the dotfiles (FPS + gamemode indicator; gamescope does the frame limiting)
  - while a game runs, `gamemoded -s` should say "gamemode is active"
- [ ] seat management: `seatd` + `turnstile` instead of elogind
  (see https://docs.voidlinux.org/config/session-management.html)
  - don't run elogind and seatd together
  - poweroff/suspend: `doas poweroff`, `doas zzz` (no loginctl)
  - polkit prompts (e.g. mounting drives in Thunar) generally need elogind - use doas instead
- [ ] minimal service set - no TLP, zram, earlyoom, iwd, unbound, cronie or logging:
  ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] locate (only if you install one, e.g. `plocate`): no cron, so refresh its database by hand - `doas updatedb`
- [ ] TRIM: manual, no job and no `discard` - run every month or so:
  `doas fstrim -av` (trims every mounted filesystem that supports it and shows how much)
- [ ] kernel options (in the Limine hook): `loglevel=4 nowatchdog mitigations=off ipv6.disable=1`
- [ ] optional, test before keeping: sched_ext scheduler (the `scx` package, e.g. `scx_lavd`) - compare frame
  times with MangoHud with and without it; only keep it if it measurably helps.
  **On the laptop (Oct 2026) `scx_lavd` 1.1.3 froze the whole system on mainline 7.2** with both `--autopower`
  and `--autopilot` (`sched_ext: ... disabled (runnable task stall)` in the kernel log) - the `scx` package was
  older than the kernel's sched_ext interface. So:
  - only try it once its output no longer shows `member ... not found in kernel` and the kernel log no
    longer shows `sched_ext: Writing directly to p->scx.slice/dsq_vtime is deprecated`
  - test by hand first (`doas scx_lavd --autopilot` in a terminal, Ctrl+C to stop) - **not** as a runit
    service: a stalled scheduler gets kicked out once, but runit restarts it straight away and it freezes again
  - check afterwards: `doas dmesg | rg 'runnable task stall'`
  - the 7800X3D has a single CCD, so the "AMD 3D V-Cache optimizer" from CachyOS's wiki doesn't apply
- [ ] move the backup off the SATA SSD: mount it with your ownership, upload the phone photos (~50 GB) and
  anything else to the uni Google Drive from Firefox, copy the rest into `~`, then unmount:
  ```sh
  doas mount -t ntfs3 -o uid=1000,gid=1000 /dev/sdXN /mnt
  # upload / copy from /mnt/backup
  doas umount /mnt
  ```
- [ ] once the backup is safe: format the SATA SSD as ext4 and mount it for `~/Games`. `nofail` matters: Void
  drops to an emergency shell at boot if a mount in fstab fails, so without it a dead or unplugged SSD
  would stop the PC booting:
  ```sh
  # check the device with lsblk first - this wipes it
  doas mkfs.ext4 -L games /dev/sdXN
  mkdir -p ~/Games
  uuid=$(doas blkid -s UUID -o value /dev/sdXN)
  echo "UUID=$uuid /home/bradley/Games ext4 defaults,noatime,nofail 0 2" \
      | doas tee -a /etc/fstab
  doas mount ~/Games && doas chown bradley:bradley ~/Games
  ```
- [ ] once everything's set up, save the desktop's own lists:
  ```sh
  xbps-query -m > ~/.config/system-configs/packages-$(hostname).txt
  ls /var/service > ~/.config/system-configs/services-$(hostname).txt
  ```

## 12. Theming

`.zprofile`, the GTK settings files and `qt6ct.conf` all come with the dotfiles, but the themes themselves and
the gsettings values don't:

```sh
# GTK theme, icons, qt6ct and the Breeze Qt style -
# the exact packages saved on the laptop in step 0
doas xbps-install -S $(cat ~/.config/system-configs/themes-void.txt)
# gsettings needs the schemas and the dconf backend, or the values below don't stick
doas xbps-install -S gsettings-desktop-schemas dconf
```

- [ ] cursor theme: Bibata is installed by hand, not from a package - download it from its releases:
  ```sh
  mkdir -p ~/.local/share/icons && cd ~/.local/share/icons
  base=https://github.com/ful1e5/Bibata_Cursor/releases/latest/download
  curl -fLO "$base/Bibata-Modern-Classic.tar.xz"
  tar -xf Bibata-Modern-Classic.tar.xz && rm Bibata-Modern-Classic.tar.xz
  ```
- [ ] `~/.config/assets` is a symlink to `/usr/share/themes/Breeze-Dark/assets` (used by the GTK 4 theme) -
  check it resolves now that Breeze-Dark is installed: `ls ~/.config/assets/ | head`
- [ ] gsettings - GTK apps on Wayland read these, and they live in the binary `~/.config/dconf/user`,
  which isn't in the repo. dconf saves through dwl's D-Bus session bus, so run these **in foot inside dwl** -
  from the bare tty the values silently don't save:
  ```sh
  gsettings set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
  gsettings set org.gnome.desktop.interface cursor-size 32
  gsettings set org.gnome.desktop.interface font-name 'DepartureMono Nerd Font Mono 16.5'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  ```
- [ ] cursor size 32 also needs the dwl `cursorsize` patch (on the `desktop` branch after the merge in step 0) -
  `echo $XCURSOR_SIZE` inside dwl should print `32`
