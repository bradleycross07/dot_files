# Void Linux + dwl install checklist

Rebuilding this setup on a fresh machine. Hostnames: laptop is `void`, desktop is `void-desktop`
(see `.chezmoiignore` for what each machine skips).

Repos:
- dotfiles: `github.com/bradleycross07/dot_files` (branch `void-linux`)
- dwl: `github.com/bradleycross07/void-dwl-config` (private; upstream is Codeberg dwl)

---

## 0. Before you start

Do these first - follow the rest of this file on the laptop screen.

### Save and push everything
- [ ] refresh the lists: `xbps-query -m > ~/.config/system-configs/packages-void.txt` and
      `ls /var/service > ~/.config/system-configs/services-void.txt`
- [ ] `chezmoi diff` is empty, then commit + push the dotfiles
- [ ] dwl: commit + push `main` (create the `desktop` branch now or during step 8)

### Ventoy USB
- [ ] Void live ISO on it (an older ISO is fine - `xbps-install -Su` brings everything up to date)
- [ ] folder `ssh key` on the Ventoy data partition with `github-void` and `github-void.pub`
      (exFAT has no Unix permissions - the `chmod` in step 2 fixes that after copying)
- [ ] game saves: `~/.config/unity3d` from the laptop
- [ ] `/etc/wireguard/windscribe.conf` only if the VPN is wanted on this machine
- [ ] after setup: delete the key from the USB

### Backing up the old Windows drives (the old PC can't boot, so do it from Linux)
Plan: free space on the SATA SSD, copy the NVMe's data onto it, install Void on the NVMe, then
sort the backup out from the finished desktop, and only then format the SATA SSD.

1. Boot the Void live ISO on the new PC and log in as `root` (password `voidlinux`)
2. Find the partitions: `lsblk -f` (the big NTFS partition on each drive)
3. Mount both:
   ```sh
   xbps-install -S ntfs-3g           # live session only, for ntfsfix if needed
   mkdir -p /mnt/win /mnt/sata
   mount -t ntfs3 -o ro /dev/nvme0n1pX /mnt/win      # Windows drive, read-only
   mount -t ntfs3 /dev/sdaX /mnt/sata                # SATA SSD, read-write
   ```
   If the SATA mount refuses ("dirty" volume - Windows Fast Startup), run `ntfsfix -d /dev/sdaX` and retry.
4. Delete the games from `/mnt/sata` to make room (they can be redownloaded)
5. Copy what's wanted from the Windows drive, e.g.
   ```sh
   mkdir -p /mnt/sata/backup
   cp -a "/mnt/win/Users/<name>/Documents" /mnt/sata/backup/
   cp -a /mnt/win/Xilinx /mnt/sata/backup/            # year 1 Vivado projects
   ```
   Also worth a look: `Users/<name>/Pictures`, `Desktop` and `Downloads` (AppData isn't needed -
   game saves are already backed up elsewhere)
6. `umount /mnt/win /mnt/sata` - then carry on with step 1 (which wipes only the NVMe)
7. Once the desktop is set up: upload the phone photos (~50 GB) and anything else to the uni
   Google Drive from Firefox, copy the rest to `~`, THEN reformat the SATA SSD as ext4 for games

### Disk layout
- NVMe: EFI 512 MiB FAT32 mounted at **/boot** (Limine reads the kernel from it - see step 1)
  + ext4 root, no swap
- SATA SSD: ext4, games (`~/Games`), formatted only after the backup is safe
  (Linux reads/writes NTFS fine via the kernel ntfs3 driver, but games and Proton need ext4: permissions, symlinks)

### BIOS / UEFI (desktop)
- [ ] update the BIOS first (newest AGESA for the 7800X3D and B850)
- [ ] UEFI only: CSM off, Secure Boot off, TPM off
- [ ] EXPO on for the DDR5-6000 CL30 kit - first boot can sit on a black screen for a few
      minutes while the memory trains; that's normal
- [ ] Resizable BAR (and Above 4G Decoding) on for the RX 9070

### Things to expect
- [ ] the live ISO's kernel may be too old for the RX 9070 (RDNA4) - fine for a TTY install;
      full GPU support comes with `linux-mainline` + recent Mesa
- [ ] ethernet cable plugged in (the onboard wifi isn't used)

## 1. Base install

Manual chroot install following https://docs.voidlinux.org (glibc, x86_64).

- [ ] ext4 root mounted with `noatime`, `/tmp` as tmpfs (`defaults,nosuid,nodev`)
      EFI on `/boot/efi` (laptop, GRUB) or on `/boot` (desktop, Limine)
- [ ] set the hostname (`void` or `void-desktop`) - chezmoi relies on it
- [ ] user `bradley` in groups: `wheel users audio video input plugdev`
      plus `socklog` on the laptop, `_seatd` on the desktop
- [ ] shell: `zsh`
- [ ] `opendoas` instead of sudo - in the chroot, give it a minimal config so `doas` works on first boot
      (the full one is restored in step 4):
      `echo 'permit persist bradley as root' > /etc/doas.conf && chmod 0400 /etc/doas.conf`

### xbps pins: do this in the live environment, BEFORE installing base-system

With the new root mounted at `/mnt`:

```sh
mkdir -p /mnt/etc/xbps.d
printf 'ignorepkg=linux\nignorepkg=linux-headers\n' > /mnt/etc/xbps.d/mainline.conf
printf 'ignorepkg=linux-firmware-nvidia\n' > /mnt/etc/xbps.d/ignore.conf
```

Then install `linux-mainline` alongside `base-system` in the same command.
Inside the chroot, confirm before rebooting:

```sh
xbps-query -l | grep linux   # want linux-mainline, NOT plain linux
```

> Don't apply the dotfiles in the chroot - you're root there, so chezmoi would set up `/root`.
> Boot into the new system first and log in as `bradley`.


### Desktop bootloader: Limine (instead of GRUB)

Limine only reads FAT, so the kernels and initramfs live on the EFI partition itself, mounted at `/boot`.
That's why the EFI partition holds more than the laptop's (GRUB's) few hundred KB - each kernel +
initramfs is tens of MB. 512 MiB is plenty if old kernels are cleaned up (`doas vkpurge rm all`).

Inside the chroot:

```sh
xbps-install -S limine efibootmgr
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Void Linux" --loader '\EFI\BOOT\BOOTX64.EFI'
```

(check the real path of `BOOTX64.EFI` with `xbps-query -f limine | grep -i efi` - copy it again whenever the `limine` package updates)

Kernel update hook - rewrites `/boot/limine.conf` for each new kernel, so an update never leaves a stale entry.
Save as `/etc/kernel.d/post-install/60-limine` and `chmod +x` it:

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

Run it once by hand for the kernel already installed, then check the result:

```sh
/etc/kernel.d/post-install/60-limine linux-mainline "$(ls /boot | sed -n 's/^vmlinuz-//p' | sort -V | tail -1)"
cat /boot/limine.conf
ls /boot        # vmlinuz-<version> and initramfs-<version>.img must both be there
```

### Remove leftover Windows boot entries

Wiping the NVMe removes Windows Boot Manager's files, but the firmware can keep its menu entry:

```sh
efibootmgr                     # list entries
efibootmgr -b 0001 -B          # delete one by its number (e.g. Boot0001 "Windows Boot Manager")
```

## 2. First boot: dotfiles (chezmoi)

Log in as `bradley` on tty1, connect to the network, then:

```sh
doas xbps-install -S chezmoi git
chezmoi init --branch void-linux --apply https://github.com/bradleycross07/dot_files.git
```

- [ ] SSH key for GitHub + commit signing: copy `github-void` and `github-void.pub` from USB 2
      into `~/.ssh/`, then `chmod 700 ~/.ssh && chmod 600 ~/.ssh/github-void`
      (same filename, so `.gitconfig` works unchanged; already on GitHub for auth + signing)
- [ ] `gh auth login` (token stays local, never commit `~/.config/gh`)
- [ ] switch the chezmoi remote to SSH if pushing from this machine

## 3. Repositories and packages

```sh
doas xbps-install -S void-repo-nonfree
doas xbps-install -Su
```

The xbps pins were already created in step 1; the copies in `~/.config/system-configs` are the backup.

Install packages by hand, one group at a time, as each step needs them - the laptop's list
(`~/.config/system-configs/packages-void.txt`) is a reference to pick from, not something to install wholesale.

Never needed on the desktop: `tlp`, `zramen`, `earlyoom`, `iwd`, `grub`/`grub-x86_64-efi` (Limine instead),
`unbound`, `cronie`, `socklog-void`, `elogind` (seatd + turnstile instead), plus the laptop-only apps in step 11.

Example - the session basics for dwl:

```sh
doas xbps-install -S seatd turnstile pipewire wireplumber easyeffects swayidle waylock wlopm \
    wl-clipboard foot fuzzel power-profiles-daemon
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
| `doas.conf`          | `/etc/doas.conf`              | `chmod 0400`; passwordless poweroff/reboot/zzz |
| `grub`               | `/etc/default/grub`           | laptop only; `doas update-grub` |
| `iwd-main.conf`      | `/etc/iwd/main.conf`          | laptop only (wifi)        |
| `nftables.conf`      | `/etc/nftables.conf`          | check: `nft -c -f`        |
| `rc.conf`            | `/etc/rc.conf`                | template: KEYMAP `uk` laptop, `us` desktop |
| `tlp.conf`           | `/etc/tlp.conf`               | laptop only               |
| `unbound.conf`       | `/etc/unbound/unbound.conf`   | laptop only; `unbound-checkconf` |
| `zramen.conf`        | `/etc/sv/zramen/conf`         | laptop only               |
| `dhcpcd.conf`        | `/etc/dhcpcd.conf`            | template: unbound on laptop, Cloudflare on desktop |

```sh
cd ~/.config/system-configs
# both machines:
doas cp 99-network.conf /etc/sysctl.d/
doas cp doas.conf /etc/doas.conf && doas chmod 0400 /etc/doas.conf
doas cp nftables.conf /etc/nftables.conf && doas nft -c -f /etc/nftables.conf
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

Not backed up on purpose (machine-specific or secret): `/etc/fstab`, `/etc/wireguard/`, `/var/lib/iwd/`.

## 5. Services (runit)

Per-machine lists saved as `~/.config/system-configs/services-<hostname>.txt`.

```sh
# both machines:
for s in dbus udevd dhcpcd chronyd nftables rtkit inputplumber; do
  doas ln -s /etc/sv/$s /var/service/
done

# laptop only:
for s in elogind iwd unbound tlp zramen earlyoom cronie socklog-unix nanoklogd; do
  doas ln -s /etc/sv/$s /var/service/
done

# desktop only: seatd + turnstile instead of elogind, power-profiles-daemon instead of TLP
for s in seatd turnstiled power-profiles-daemon; do
  doas ln -s /etc/sv/$s /var/service/
done
# then, once: powerprofilesctl set performance   (the choice is remembered across reboots)
```

- [ ] only keep `agetty-tty1` and `agetty-tty2`: `doas rm /var/service/agetty-tty{3,4,5,6}`
- [ ] irqbalance, bluetoothd, NetworkManager, wpa_supplicant: leave disabled

## 6. Shell and editor

```sh
git clone https://github.com/zdharma-continuum/zinit.git ~/.local/share/zinit/zinit.git
```

- Neovim: lazy.nvim bootstraps itself on first launch
- dwl is started by typing `dwl` on tty1 (function in `.zshrc`)

## 7. Audio

Already handled by the dotfiles:
- `~/.config/pipewire/pipewire.conf.d/` - rates + symlinks that make PipeWire launch WirePlumber and pipewire-pulse
- EasyEffects mic chain: `~/.config/easyeffects/db/` (gate, compressor, rnnoise)

Manual:
- [ ] pick default devices in pavucontrol (headset sink, `easyeffects_source` as mic)
- [ ] laptop: set built-in speakers profile to Off if not wanted

## 8. Built from source (`~/.local/src`)

### dwl
```sh
git clone git@github.com:bradleycross07/void-dwl-config.git ~/.local/src/dwl
cd ~/.local/src/dwl
git remote add upstream https://codeberg.org/dwl/dwl.git
make && doas make install
```
- desktop: use the `desktop` branch (monitor rule, no brightness keys, no Mod+v clipboard picker)
- dwl runs `~/.local/bin/autostart.sh` at startup (a template):
  - laptop: keyring, polkit agent, PipeWire + EasyEffects + audio idle inhibit, kanshi,
    xsettingsd, gammastep, clipboard history, swayidle (lock, screen off, poweroff after 3 h)
  - desktop: PipeWire, EasyEffects (mic for Discord) and swayidle (lock after 10 min, screen off after 15 - protects the OLED)
- quitting dwl stops everything autostart.sh started (the autostart patch kills its process group)
- needs: `wlroots0.20-devel` and dwl's other build deps

### Aurelia
- own tweaks on the `local` branch, rebased onto `origin/main`
- build, copy the binary to `~/.local/bin/aurelia`, then `cargo clean`
- game library: `~/Games/Aurelia`

### InputPlumber
- build per its README, enable the `inputplumber` service (step 4)

### void-packages (restricted: Discord, Spotify)
```sh
git clone https://github.com/void-linux/void-packages.git ~/.local/src/void-packages
cd ~/.local/src/void-packages
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
./xbps-src pkg discord && doas xbps-install -R hostdir/binpkgs/nonfree discord
./xbps-src pkg spotify && doas xbps-install -R hostdir/binpkgs/nonfree spotify
```

## 9. Manually installed apps

| App           | Location                         | Notes                                   |
| ------------- | -------------------------------- | --------------------------------------- |
| Obsidian      | `~/.local/opt/Obsidian`          | AppImage extracted; wrapper in `~/.local/bin` |
| Motrix        | `~/.local/opt/Motrix`            | AppImage extracted; wrapper in `~/.local/bin` |
| VS Code       | `~/.local/opt/VSCode-linux-x64`  | install/update with `update-vscode` (laptop only) |
| Archipelago   | `~/.local/opt/Archipelago`       | wrapper in `~/.local/bin`               |
| Lumafly       | `~/.local/share/lumafly`         | wrapper in `~/.local/bin`               |
| ProjectLibre  | `/usr/share/projectlibre`        | jar; icon in hicolor 128x128 (laptop only) |
| Vivado 2023.2 | `/tools/Xilinx`                  | ML Standard, Zynq-7000; launch via `~/.local/bin/vivado` (laptop only) |

After installing Vivado, fix the folders its installer makes world-writable:
```sh
chmod 755 ~/.config/autostart ~/.config/menus
```

## 10. Secrets and personal setup (never in the repo)

- [ ] WireGuard: download a Windscribe config to `/etc/wireguard/windscribe.conf` (`vpnup` / `vpndown`)
- [ ] eduroam: run the university CAT installer (laptop)
- [ ] game saves: restore `~/.config/unity3d` from backup

## 11. Desktop-specific (void-desktop)

- [ ] GPU (RX 9070, RDNA4): recent Mesa + `mesa-vulkan-radeon`, AMD firmware; mainline kernel helps
- [ ] dwl `desktop` branch: monitor rule for the XG27ACDNG, 2560x1440 @ 360 Hz
- [ ] mpv: `gpu-api=vulkan`, heavier scalers, add `av1` to `hwdec-codecs`
- [ ] minimal service set - no TLP, zram, earlyoom, iwd, unbound, cronie or logging:
      ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] seat management: `seatd` + `turnstile` instead of elogind
      (see https://docs.voidlinux.org/config/session-management.html)
      - don't run elogind and seatd together
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
- [ ] laptop-only apps, skip on the desktop: VS Code, ProjectLibre, Vivado, `tailscale`
      - `mimeapps.list` opens code/text files with `code.desktop`: set those to `nvim.desktop` on the desktop
      - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
      - add `gnome-keyring` back if signing into VS Code/GitHub on the desktop
- [ ] power: `power-profiles-daemon` set to `performance` (never run it alongside TLP)
- [ ] `rc.conf` KEYMAP `us` (US keyboard only) - automatic via the `rc.conf` template
- [ ] bootloader: Limine instead of GRUB - full steps in step 1 (EFI at `/boot`, kernel hook)
      - kernel options: the laptop's `loglevel=4 nowatchdog mitigations=off`, plus `ipv6.disable=1` (IPv4 only)
- [ ] once the backup is safe: format the SATA SSD as ext4 and mount it for `~/Games`
