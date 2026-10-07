# Void Linux + dwl install checklist

Rebuilding this setup on a fresh machine. Hostnames: laptop is `void`, new PC is `void-desktop`.

(look at `.chezmoiignore` to see what each machine skips)

Repos:
- dotfiles: `github.com/bradleycross07/dot_files` (public; branch `void-linux`)
- dwl: `github.com/bradleycross07/void-dwl-config` (private; upstream is Codeberg dwl)

---

## 0. Before starting

Do these first, then keep this checklist open on the laptop while installing on the PC.

### Save and push everything
- [ ] refresh the lists: `xbps-query -m > ~/.config/system-configs/packages-void.txt` and
      `ls /var/service > ~/.config/system-configs/services-void.txt`
- [ ] `chezmoi diff` is empty, then commit + push the dotfiles
- [ ] dwl: commit + push `main`, then create and push the `desktop` branch now
      (step 8 checks it out from a fresh clone, so it must already be on GitHub):
      `git switch -c desktop && git push -u origin desktop`
- [ ] Aurelia: export the `local` branch's patches into the dotfiles repo (they only exist as local commits):
      `cd ~/.local/src/Aurelia && git format-patch origin/main..local -o "$(chezmoi source-path)/patches/aurelia"`
- [ ] optional - spotatui: same for its `local` branch:
      `cd ~/.local/src/spotatui && git format-patch origin/main..local -o "$(chezmoi source-path)/patches/spotatui"`
      (`patches` is listed in `.chezmoiignore`, so it stays in the repo and is never copied into `~`)
- [x] InputPlumber's runit service is hand-made, so it's backed up in `~/.config/system-configs/sv-inputplumber`
      (`run` and `log/run` only - never `supervise`, that's runit's runtime state)

### Ventoy USB
- [x] Void live ISO on it (an older ISO is fine - `xbps-install -Su` brings everything up to date)
- [ ] folder `ssh-key` on the Ventoy data partition with `github-void`, `github-void.pub` and `config`
      from `~/.ssh/` (the key has a non-default name, so `config` is what tells SSH to use it for GitHub;
      exFAT has no Unix permissions - the `chmod` in step 2 fixes that after copying)
- [ ] game saves: `~/.config/unity3d` from the laptop
- [ ] after setup: delete the key from the USB

### Backing up the old Windows drives (from the live environment, to avoid Windows altogether)
The plan: free space on the SATA SSD (delete the Games folder), copy what's needed from the NVMe onto it, install Void on the NVMe, sort the backup out from the finished PC, and only then format the SATA SSD at the very end.

1. Boot the Void live ISO on the new PC and log in as `root`
2. Find the partitions: `lsblk -f` or `fdisk -l` (the big NTFS partition on each drive). The names below are examples - the Ventoy USB is also an `sdX` drive, probably `sda`, so check the sizes before mounting anything.
3. Mount both:
   ```sh
   xbps-install -Su xbps             # an older ISO's xbps must be updated before anything else installs
   xbps-install -S ntfs-3g           # live session only, for ntfsfix if needed
   mkdir -p /mnt/win /mnt/sata
   mount -t ntfs3 -o ro /dev/nvme0n1pX /mnt/win      # Windows drive, read-only
   mount -t ntfs3 /dev/sdbX /mnt/sata                # SATA SSD, read-write
   ```
   Fast Startup is already disabled in Windows, but if the SATA mount still refuses ("dirty" volume),
   run `ntfsfix -d /dev/sdbX` and retry.
4. Delete the games from `/mnt/sata` to make room if needed
5. Copy what's wanted from the Windows drive (`--preserve=timestamps` instead of `-a`, since NTFS can't store Unix owners/permissions), e.g.
   ```sh
   mkdir -p /mnt/sata/backup
   cp -r --preserve=timestamps /mnt/win/Users/Bradley/Documents /mnt/sata/backup/   # Windows user is "Bradley"
   cp -r --preserve=timestamps /mnt/win/Xilinx /mnt/sata/backup/                    # Year 1 Vivado projects
   ```
   Also worth a look: `Pictures`, `Desktop` and `Downloads`
6. `umount /mnt/win /mnt/sata` - then carry on with section 1 (which wipes only the NVMe)
7. Once the desktop is set up: upload the phone photos (~50 GB) and anything else to the uni Google Drive from Firefox, copy the rest to `~`, THEN reformat the SATA SSD as ext4 for games

### Disk layout
- NVMe: EFI 512 MiB FAT32 mounted at `/boot` (Limine reads the kernel from it)
  - ext4 root, no swap
- SATA SSD: ext4, games (`~/Games`), formatted only after the backup is safe
  (until then Linux reads/writes its NTFS fine via the kernel ntfs3 driver)

### BIOS / UEFI (desktop)
- [ ] update the BIOS first (newest for the B850 board)
- [ ] UEFI only: CSM off, Secure Boot off, TPM off
- [ ] EXPO on for the DDR5-6000 CL30 kit - the first boot can sit on a black screen for a few
      minutes while the RAM trains
- [ ] Resizable BAR (and Above 4G Decoding) on for the RX 9070 (free performance boost)

### Things to expect
- [ ] the live ISO's kernel may be too old for the RX 9070 (RDNA4) - fine for a TTY install;
      full GPU support comes with `linux-mainline` + recent Mesa
- [x] ethernet cable plugged in (the onboard wifi isn't used, no iwd)

## 1. Base install

Manual chroot install following https://docs.voidlinux.org (glibc, x86_64).

In order: partition and mount, set the xbps pins, install `base-minimal` plus the extras below, then chroot.

### xbps pins: do this in the live environment, BEFORE installing anything

With the new root mounted at `/mnt`:

```sh
mkdir -p /mnt/etc/xbps.d
printf 'ignorepkg=linux\nignorepkg=linux-headers\n' > /mnt/etc/xbps.d/mainline.conf
printf 'ignorepkg=linux-firmware-nvidia\n' > /mnt/etc/xbps.d/ignore.conf
```

### Install the base system (`base-minimal`, not `base-system`)

`base-minimal` is the lean option, so everything the system needs to boot and get online is listed explicitly. Follow the Void docs for the rest of the command (copying the xbps keys, `XBPS_ARCH`):

```sh
# desktop
xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal linux-mainline dracut eudev e2fsprogs kbd ncurses iproute2 iputils \
    dhcpcd dbus opendoas zsh \
    linux-firmware-amd linux-firmware-network dosfstools seatd

# laptop (for reference)
xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal linux-mainline dracut eudev e2fsprogs kbd ncurses iproute2 iputils \
    dhcpcd dbus opendoas zsh \
    linux-firmware-amd wifi-firmware iwd grub-x86_64-efi socklog-void
```

What each extra is for: `linux-mainline` + `dracut` kernel and its initramfs, `eudev` device manager (udevd - dwl, libinput and seatd need it), `e2fsprogs` checks the ext4 root at boot, `kbd` applies the `rc.conf` keymap, `ncurses` terminal handling, `iproute2`/`iputils` (`ip`, `ping`), `dhcpcd` network, `dbus` + `opendoas` + `zsh` for the user, `linux-firmware-amd` GPU/CPU firmware (the RX 9070 won't start without it), `linux-firmware-network` the onboard ethernet chip's firmware, `dosfstools` checks the FAT32 EFI partition (where Limine's kernels live), `seatd` seat management.

Once inside the chroot, confirm:

`xbps-query linux >/dev/null && echo "plain linux IS installed - remove it" || echo "ok: no plain linux"`

`xbps-query -l | command grep 'linux-mainline\|^ii linux[0-9]'`

### Inside the chroot

- [ ] `/etc/fstab` (generated with `xgenfstab -U /mnt > /mnt/etc/fstab` before chrooting, then checked):
      ext4 root with `noatime`, `/tmp` as tmpfs (`defaults,nosuid,nodev`),
      EFI on `/boot/efi` (laptop, GRUB) or on `/boot` (desktop, Limine)
- [ ] set the hostname (`void` or `void-desktop`) - chezmoi relies on it
- [ ] timezone: `ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime`
- [ ] locale (glibc): uncomment `en_GB.UTF-8 UTF-8` in `/etc/default/libc-locales`, set `LANG=en_GB.UTF-8` in
      `/etc/locale.conf` (install `glibc-locales` first if it's missing; `xbps-reconfigure -fa` at the end generates it)
- [ ] root password, as a way back in if `doas.conf` ever breaks: `passwd`
- [ ] user `bradley` with shell `zsh` and a password, in groups `wheel users audio video input plugdev`,
      plus `_seatd` on the desktop or `socklog` on the laptop (those groups exist because the packages were installed above):
      ```sh
      useradd -m -s /bin/zsh -G wheel,users,audio,video,input,plugdev,_seatd bradley   # desktop
      passwd bradley
      ```
- [ ] `opendoas` instead of sudo - give it a minimal config so `doas` works on first boot
      (the full one is restored in step 4), and check it before relying on it:
      ```sh
      echo 'permit persist bradley as root' > /etc/doas.conf && chmod 0400 /etc/doas.conf
      doas -C /etc/doas.conf && echo "doas.conf ok"
      ```

Still in the chroot, enable networking so the first boot is online (in a chroot, services are enabled
in `/etc/runit/runsvdir/default/`, not `/var/service/`):

```sh
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default/          # desktop + laptop ethernet
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
ln -s /etc/sv/udevd /etc/runit/runsvdir/default/
ln -s /etc/sv/iwd /etc/runit/runsvdir/default/             # laptop only (wifi)
```

> Don't apply the dotfiles in the chroot - you're root there, so chezmoi would set up `/root`.
> Boot into the new system first and log in as `bradley`.


### Desktop bootloader: Limine (instead of GRUB)

Limine only reads FAT, so the kernels and initramfs live on the EFI partition itself, mounted at `/boot`.
That's why the EFI partition holds more than the laptop's (GRUB's) few hundred KB - each kernel + initramfs is tens of MB. 512 MiB is plenty if old kernels are cleaned up (`doas vkpurge rm all`).

Inside the chroot:

```sh
xbps-install -S limine efibootmgr
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Void Linux" --loader '\EFI\BOOT\BOOTX64.EFI'
```

(check the real path of `BOOTX64.EFI` with `xbps-query -f limine | grep -i efi` - copy it again whenever the `limine` package updates)

Kernel update hook - rewrites `/boot/limine.conf` for each new kernel, so an update never leaves a stale entry. Save as `/etc/kernel.d/post-install/60-limine` and `chmod +x` it:

```sh
#!/bin/sh
# called by xbps after installing a kernel: $1 = package, $2 = version
VERSION="$2"
ROOT_UUID=$(findmnt -no UUID /)
cat > /boot/limine.conf <<CONF
timeout: 3

/Void Linux ($VERSION)
    protocol: linux
    path: boot():/vmlinuz-$VERSION
    module_path: boot():/initramfs-$VERSION.img
    cmdline: root=UUID=$ROOT_UUID ro loglevel=4 nowatchdog mitigations=off ipv6.disable=1
CONF
```

### Finish the chroot (both machines)

With the hook in place (desktop) or GRUB installed (laptop), configure every package. This also runs dracut
and the kernel hooks, so it writes the initramfs and `limine.conf`:

```sh
xbps-reconfigure -fa
cat /boot/limine.conf      # desktop: check the entry
ls /boot                   # vmlinuz-<version> and initramfs-<version>.img must both be there
```

If `limine.conf` is missing, run the hook by hand:

```sh
/etc/kernel.d/post-install/60-limine linux-mainline "$(ls /boot | sed -n 's/^vmlinuz-//p' | sort -V | tail -1)"
```

### Remove leftover Windows boot entries

Wiping the NVMe removes Windows Boot Manager's files, but the firmware can keep its menu entry:

```sh
efibootmgr                     # list entries
efibootmgr -b 0001 -B          # delete one by its number (e.g. Boot0001 "Windows Boot Manager")
```

## 2. First boot: dotfiles (chezmoi)

Log in as `bradley` on tty1 (dhcpcd from step 1 should already have you online - check with `ping -c 3 voidlinux.org`), then:

```sh
doas xbps-install -S chezmoi git openssh
chezmoi init --branch void-linux --apply https://github.com/bradleycross07/dot_files.git
```

> The applied `.zshrc` expects its tools - until step 6 is done, new shells will print errors. Do step 6 straight after this one.

- [ ] SSH key for GitHub + commit signing: mount the Ventoy data partition (partition 1) and copy the key over:
      ```sh
      doas mount /dev/sdX1 /mnt
      mkdir -p ~/.ssh && cp /mnt/ssh-key/github-void /mnt/ssh-key/github-void.pub /mnt/ssh-key/config ~/.ssh/
      chmod 700 ~/.ssh && chmod 600 ~/.ssh/github-void ~/.ssh/config
      doas umount /mnt
      ```
      (same filename, so `.gitconfig` works unchanged; already on GitHub for auth + signing)
      test with: `ssh -T git@github.com`
- [ ] `doas xbps-install -S github-cli` then `gh auth login` (token stays local, never commit `~/.config/gh`)
- [ ] switch the chezmoi remote to SSH to push from this machine:
      `chezmoi git -- remote set-url origin git@github.com:bradleycross07/dot_files.git`

## 3. Repositories and packages

```sh
doas xbps-install -S void-repo-nonfree
doas xbps-install -Su
```

The xbps pins were already created in step 1; the copies in `~/.config/system-configs` are the backup.

Install packages by hand, one group at a time, as each step needs them - the laptop's list
(`~/.config/system-configs/packages-void.txt`) is a reference to pick from, not something to install wholesale.

Never needed on the desktop: `tlp`, `zramen`, `earlyoom`, `iwd`, `wifi-firmware`, `grub-x86_64-efi` (Limine instead),
`unbound`, `cronie`, `socklog-void`, `elogind` (seatd + turnstile instead), `yarn`, plus the laptop-only apps in step 11.

Examples - packages the later steps rely on:

```sh
# services enabled in step 5
doas xbps-install -S chrony nftables rtkit turnstile power-profiles-daemon
# dwl session
doas xbps-install -S pipewire wireplumber alsa-pipewire easyeffects swayidle waylock wlopm wl-clipboard foot fuzzel
```

> Each machine keeps its own lists - refresh them with:
> `xbps-query -m > ~/.config/system-configs/packages-$(hostname).txt`
> `ls /var/service > ~/.config/system-configs/services-$(hostname).txt`

## 4. System configs (/etc)

`dhcpcd.conf` and `rc.conf` (and `~/.local/bin/autostart.sh`) are chezmoi templates (`.tmpl` in the repo):
their per-machine parts are filled in from the hostname. Edit them with `chezmoi edit` - `chezmoi re-add` skips templates.

Copies live in `~/.config/system-configs` (applied by chezmoi in step 2).

| Backup file          | Restore to                    | Notes                     |
| -------------------- | ----------------------------- | ------------------------- |
| `99-network.conf`    | `/etc/sysctl.d/`              | BBR + fq                  |
| `99-vm.conf`         | `/etc/sysctl.d/`              | zram-tuned, laptop only   |
| `doas.conf`          | `/etc/doas.conf`              | check with `doas -C` first; `chmod 0400`; passwordless poweroff/reboot/zzz |
| `grub`               | `/etc/default/grub`           | laptop only; `doas update-grub` |
| `iwd-main.conf`      | `/etc/iwd/main.conf`          | laptop only (wifi)        |
| `nftables.conf`      | `/etc/nftables.conf`          | check with `nft -c -f` first |
| `rc.conf`            | `/etc/rc.conf`                | template: KEYMAP `uk` laptop, `us` desktop |
| `tlp.conf`           | `/etc/tlp.conf`               | laptop only               |
| `unbound.conf`       | `/etc/unbound/unbound.conf`   | laptop only; `unbound-checkconf` |
| `zramen.conf`        | `/etc/sv/zramen/conf`         | laptop only               |
| `dhcpcd.conf`        | `/etc/dhcpcd.conf`            | template: unbound on laptop, Cloudflare on desktop |
| `60-limine`          | `/etc/kernel.d/post-install/` | desktop only; `chmod +x`  |
| `xbps.d/*.conf`      | `/etc/xbps.d/`                | the pins from step 1      |

```sh
cd ~/.config/system-configs
# both machines - check doas.conf and nftables.conf BEFORE copying them into /etc:
doas -C doas.conf && doas cp doas.conf /etc/doas.conf && doas chmod 0400 /etc/doas.conf
doas nft -c -f nftables.conf && doas cp nftables.conf /etc/nftables.conf
doas cp 99-network.conf /etc/sysctl.d/
doas cp rc.conf /etc/rc.conf          # KEYMAP already filled in per machine by chezmoi
doas cp dhcpcd.conf /etc/dhcpcd.conf   # DNS line already filled in per machine by chezmoi
# laptop only (chezmoi doesn't even place these files on the desktop):
doas cp 99-vm.conf /etc/sysctl.d/
doas cp unbound.conf /etc/unbound/unbound.conf && doas unbound-checkconf
doas cp grub /etc/default/grub && doas update-grub
doas cp iwd-main.conf /etc/iwd/main.conf
doas cp zramen.conf /etc/sv/zramen/conf
doas cp tlp.conf /etc/tlp.conf
```

- [ ] desktop, once it's set up: back up the Limine hook and pins too:
      `cp /etc/kernel.d/post-install/60-limine ~/.config/system-configs/ && mkdir -p ~/.config/system-configs/xbps.d && cp /etc/xbps.d/*.conf ~/.config/system-configs/xbps.d/`
      then `chezmoi add` them

Not backed up on purpose (machine-specific or secret): `/etc/fstab`, `/etc/wireguard/`, `/var/lib/iwd/`.

## 5. Services (runit)

Per-machine lists saved as `~/.config/system-configs/services-<hostname>.txt`.

```sh
# both machines (dbus, dhcpcd and udevd were already enabled in step 1):
for s in chronyd nftables rtkit; do
  doas ln -s /etc/sv/$s /var/service/
done
# inputplumber: after it's built in step 8

# laptop only:
for s in elogind iwd unbound tlp zramen earlyoom cronie socklog-unix nanoklogd; do
  doas ln -s /etc/sv/$s /var/service/
done

# desktop only: seatd + turnstile instead of elogind, power-profiles-daemon instead of TLP
for s in seatd turnstiled power-profiles-daemon; do
  doas ln -s /etc/sv/$s /var/service/
done
# then, once: doas powerprofilesctl set performance   (no polkit agent without elogind; the choice is remembered across reboots)
```

- [ ] after restoring the configs in step 4: `doas sv restart dhcpcd` and `doas sysctl --system`
- [ ] only keep `agetty-tty1` and `agetty-tty2`: `doas rm /var/service/agetty-tty{3,4,5,6}`
- [ ] irqbalance, bluetoothd, NetworkManager, wpa_supplicant: leave disabled

## 6. Shell and editor

```sh
doas xbps-install -S starship zoxide fzf eza bat dust duf procs fastfetch neovim
git clone https://github.com/zdharma-continuum/zinit.git ~/.local/share/zinit/zinit.git
```

(`gh` completion in `.zshrc` needs `github-cli` from step 2)

- Neovim: lazy.nvim bootstraps itself on first launch
- dwl is started by typing `dwl` on tty1 (function in `.zshrc`)

## 7. Audio

Already handled by the dotfiles:
- `~/.config/pipewire/pipewire.conf.d/` - rates + symlinks that make PipeWire launch WirePlumber and pipewire-pulse
- EasyEffects mic chain: `~/.config/easyeffects/db/` (gate, compressor, rnnoise)

Manual:
- [ ] route ALSA through PipeWire (spotatui plays through ALSA - without this it fails with
      "Device default ... Busy"); needs `alsa-pipewire`:
      ```sh
      doas mkdir -p /etc/alsa/conf.d
      doas ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
      doas ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
      ```
- [ ] pick default devices (headset sink, `easyeffects_source` as mic) - pavucontrol, or
      `wpctl status` to find the IDs and `wpctl set-default <id>`
- [ ] laptop: set built-in speakers profile to Off if not wanted

## 8. Built from source (`~/.local/src`)

Rust builds use mold and native CPU tuning from the command line (not `~/.cargo/config.toml`), so install mold once:

```sh
doas xbps-install -S rust cargo mold
```

### dwl
```sh
doas xbps-install -S base-devel pkg-config wlroots0.20-devel xorg-server-xwayland
git clone git@github.com:bradleycross07/void-dwl-config.git ~/.local/src/dwl
cd ~/.local/src/dwl
git remote add upstream https://codeberg.org/dwl/dwl.git
git checkout desktop          # desktop only (pushed in step 0)
make && doas make install
```
(`wlroots0.20-devel` pulls in the Wayland, libinput, xkbcommon and XCB headers; `base-devel` is gcc + make;
`xorg-server-xwayland` runs X11 apps and most games)
- desktop: use the `desktop` branch (monitor rule, no brightness keys, no Mod+v clipboard picker)
- dwl runs `~/.local/bin/autostart.sh` at startup (a template):
  - laptop: keyring, polkit agent, PipeWire + EasyEffects + audio idle inhibit, kanshi,
    xsettingsd, gammastep, clipboard history, swayidle (lock, screen off, poweroff after 3 h)
  - desktop: PipeWire, EasyEffects (mic for Discord) and swayidle (lock after 10 min, screen off after 15 - protects the OLED)
- quitting dwl stops everything autostart.sh started (the autostart patch kills its process group)

### Aurelia
- needs `rust cargo mold` (and possibly `openssl-devel` - it's on the laptop's list)
- restore the local tweaks from the dotfiles repo onto a `local` branch:
  ```sh
  cd ~/.local/src/Aurelia
  git checkout -b local
  git am "$(chezmoi source-path)"/patches/aurelia/*.patch
  ```
- build with the same flags as spotatui below, copy the binary to `~/.local/bin/aurelia`, then `cargo clean`
  (`update-aurelia` from the dotfiles handles later updates)
- game library: `~/Games/Aurelia`

### InputPlumber
- needs `rust cargo libevdev-devel libiio-devel dbus-devel` (as on the laptop; its README has the full list)
- build per its README
- restore its service and enable it:
  `doas cp -r ~/.config/system-configs/sv-inputplumber /etc/sv/inputplumber && doas ln -s /etc/sv/inputplumber /var/service/`
  - desktop: then `doas rm -r /etc/sv/inputplumber/log` - it sends output to syslog (vlogger), which the desktop doesn't run

### spotatui (terminal Spotify client, ~50 MB RAM vs 1 GB+ for the official app)
```sh
doas xbps-install -S pkg-config alsa-lib-devel openssl-devel libxcb-devel
git clone https://github.com/LargeModGames/spotatui.git ~/.local/src/spotatui
cd ~/.local/src/spotatui
git checkout -b local
git am "$(chezmoi source-path)"/patches/spotatui/*.patch     # only if the patches were exported in step 0
CARGO_PROFILE_RELEASE_OPT_LEVEL=3 \
RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold" \
cargo build --release --locked --no-default-features \
    --features tui,streaming,audio-viz-cpal,scripting
cp target/release/spotatui ~/.local/bin/
cargo clean
```
- needs Rust 1.90+ (`rustc --version`) and the ALSA -> PipeWire links from step 7
- no `self-update` (would replace the self-built binary), no `telemetry`, no `mpris` (media keys aren't used)
  and no `discord-rpc` (Discord's own Spotify connection already shows the activity); the song counter
  is also off in `config.yml` (`enable_global_song_count: false`)
- `target-cpu=native` tunes for the machine it's built on, so each machine builds its own
- update: `git fetch origin && git rebase origin/main`, then build, `cp`, `cargo clean` as above
- config: `~/.config/spotatui/config.yml` comes from chezmoi (theme, keys, settings);
  `client.yml` and the login caches are NOT in the repo
- first run: choose option 2 (own Spotify app), port 8888, paste the Client ID from the
  Spotify Developer Dashboard (the same app works on both machines), then pick the `spotatui` device with `d`
- edit `config.yml` only while spotatui is closed, or change things in its settings screen and save with `Alt-s`

### void-packages (restricted: Discord, Spotify)
Spotify's official client is now only needed for offline downloads - spotatui can't play offline.
```sh
git clone https://github.com/void-linux/void-packages.git ~/.local/src/void-packages
cd ~/.local/src/void-packages
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
./xbps-src pkg discord && doas xbps-install -R hostdir/binpkgs/nonfree discord
./xbps-src pkg spotify && doas xbps-install -R hostdir/binpkgs/nonfree spotify   # optional, offline only
```

## 9. Manually installed apps (`~/.local/opt`)

Each has a small `exec` wrapper in `~/.local/bin` (VS Code is a symlink to its own `bin/code` instead).

| App           | Location                         | Notes                                   |
| ------------- | -------------------------------- | --------------------------------------- |
| Obsidian      | `~/.local/opt/Obsidian`          | AppImage extracted; install/update with `update-obsidian` |
| Motrix        | `~/.local/opt/Motrix`            | AppImage extracted; wrapper runs `AppRun` |
| VS Code       | `~/.local/opt/VSCode-linux-x64`  | install/update with `update-vscode` (laptop only) |
| Archipelago   | `~/.local/opt/Archipelago`       | wrapper runs `ArchipelagoLauncher`      |
| Lumafly       | `~/.local/opt/Lumafly`           | wrapper `cd`s into the folder first     |
| ProjectLibre  | `/usr/share/projectlibre`        | jar; icon in hicolor 128x128 (laptop only) |
| Vivado 2023.2 | `/tools/Xilinx`                  | ML Standard, Zynq-7000; launch via `~/.local/bin/vivado` (laptop only) |

After installing Vivado, fix the folders its installer makes world-writable:
```sh
chmod 755 ~/.config/autostart ~/.config/menus
```

## 10. Secrets and personal setup (never in the repo)

- [ ] laptop only - WireGuard: restore `windscribe.conf` to `/etc/wireguard/` (or download a fresh one from Windscribe), install `wireguard-tools` (`vpnup` / `vpndown`)
- [ ] eduroam: run the university CAT installer (laptop)
- [ ] game saves: restore `~/.config/unity3d` from the Ventoy USB

## 11. Desktop-specific (void-desktop)

- [ ] GPU (RX 9070, RDNA4): recent Mesa + `mesa-vulkan-radeon`, AMD firmware; mainline kernel helps
- [ ] dwl `desktop` branch: monitor rule for the XG27ACDNG, 2560x1440 @ 360 Hz
- [ ] mpv: `gpu-api=vulkan`, heavier scalers, add `av1` to `hwdec-codecs`
- [ ] minimal service set - no TLP, zram, earlyoom, iwd, unbound, cronie or logging:
      ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] seat management: `seatd` + `turnstile` instead of elogind
      (see https://docs.voidlinux.org/config/session-management.html)
      - don't run elogind and seatd together
      - after logging in, check `echo $XDG_RUNTIME_DIR` prints `/run/user/1000` - if it's empty, enable
        `manage_rundir = yes` in `/etc/turnstile/turnstiled.conf` (dwl, PipeWire and foot need it)
      - poweroff/suspend: `doas poweroff`, `doas zzz` (no loginctl)
      - polkit prompts (e.g. mounting drives in Thunar) generally need elogind - use doas instead
- [ ] DNS: Cloudflare directly via dhcpcd (no local cache/DoT); comes from the `dhcpcd.conf` template
- [ ] locate: no cron, so refresh by hand when needed - `doas updatedb`
- [ ] TRIM: manual, no job and no `discard` - run every month or so:
      `doas fstrim -av` (trims every mounted filesystem that supports it and shows how much)
- [ ] IPv4 only: `ipv6.disable=1` on the kernel command line; nftables.conf stays the same as the laptop's
- [ ] session packages to skip (autostart.sh doesn't run them on the desktop):
      `kanshi`, `gammastep`, `xsettingsd`, `polkit-gnome`, `gnome-keyring`, `cliphist`,
      `sway-audio-idle-inhibit` - keep `wl-clipboard` (screenshots), `swayidle`, `waylock`, `wlopm`, `easyeffects`
      - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
      - add `gnome-keyring` back if signing into VS Code/GitHub on the desktop
- [ ] laptop-only apps, skip on the desktop: VS Code, ProjectLibre, Vivado
      - `mimeapps.list` opens code/text files with `code.desktop`: set those to `nvim.desktop` on the desktop
- [ ] power: `power-profiles-daemon` set to `performance` (never run it alongside TLP)
- [ ] optional, test before keeping: sched_ext scheduler (`scx`, `scx-loader`, e.g. `scx_lavd`) - compare frame
      times with MangoHud with and without it; only keep it if it measurably helps
- [ ] `rc.conf` KEYMAP `us` (US keyboard only) - automatic via the `rc.conf` template
- [ ] bootloader: Limine instead of GRUB - full steps in section 1 (EFI at `/boot`, kernel hook)
      - kernel options: the laptop's `loglevel=4 nowatchdog mitigations=off`, plus `ipv6.disable=1` (IPv4 only)
- [ ] once the backup is safe: format the SATA SSD as ext4 and mount it for `~/Games`
