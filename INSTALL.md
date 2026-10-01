# Void Linux + dwl install checklist

Rebuilding this setup on a fresh machine. Hostnames: laptop is `void`, desktop is `void-desktop`
(see `.chezmoiignore` for what each machine skips).

Repos:
- dotfiles: `github.com/bradleycross07/dot_files` (branch `void-linux`)
- dwl: `github.com/bradleycross07/void-dwl-config` (private; upstream is Codeberg dwl)

---

## 0. Before you start

Do these on the laptop (or before wiping anything) - follow the rest of this file on the laptop screen.

### Save and push everything
- [ ] refresh the lists: `xbps-query -m > ~/.config/system-configs/packages-void.txt` and
      `ls /var/service > ~/.config/system-configs/services-void.txt`
- [ ] `chezmoi diff` is empty, then commit + push the dotfiles
- [ ] dwl: commit + push `main` (create the `desktop` branch now or during step 8)

### USB drives
- [ ] **USB 1 - installer:** latest Void live ISO (glibc, x86_64), written with
      `doas dd if=void-live-x86_64-*.iso of=/dev/sdX bs=4M status=progress oflag=sync`
      (double-check `/dev/sdX` with `lsblk` first - it erases that drive)
- [ ] **USB 2 - personal files** (keep it somewhere safe, it holds a private key):
  - `~/.ssh/github-void` and `~/.ssh/github-void.pub` - needed to push dotfiles and clone the private dwl repo
  - game saves: `~/.config/unity3d` (Hollow Knight, Silksong)
  - `/etc/wireguard/windscribe.conf` only if the VPN is wanted on this machine

### Drives being reused
- [ ] back up anything wanted from the ADATA 512GB NVMe and the WD Green 1TB SATA SSD - the install wipes them
- [ ] decide the layout, e.g. NVMe = system (EFI 512 MB-1 GB FAT32 + ext4 root, no swap),
      SATA SSD = games (`~/Games`)

### BIOS / UEFI (desktop)
- [ ] update the BIOS first (newest AGESA for the 7800X3D and B850)
- [ ] UEFI only (CSM off) and Secure Boot off
- [ ] EXPO on for the DDR5-6000 CL30 kit - first boot can sit on a black screen for a few
      minutes while the memory trains; that's normal
- [ ] Resizable BAR (and Above 4G Decoding) on for the RX 9070

### Things to expect
- [ ] the live ISO's kernel may be too old for the RX 9070 (RDNA4), so the installer may only show
      a basic console - fine for a terminal install; full GPU support comes with `linux-mainline` + recent Mesa
- [ ] ethernet cable plugged in (the onboard wifi isn't used)
- [ ] Limine: read Void's docs/package notes before step 1 - GRUB is the fallback if it gets fiddly

## 1. Base install

Manual chroot install following https://docs.voidlinux.org (glibc, x86_64).

- [ ] ext4 root mounted with `noatime`, EFI on `/boot/efi`, `/tmp` as tmpfs (`defaults,nosuid,nodev`)
- [ ] set the hostname (`void` or `void-desktop`) - chezmoi relies on it
- [ ] user `bradley` in groups: `wheel users audio video input plugdev`
      plus `socklog` on the laptop, `_seatd` on the desktop
- [ ] desktop: add `discard` to the root's mount options in `/etc/fstab` (continuous TRIM, so no fstrim job is needed)
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

Install everything from the saved list. Review it first - on the desktop drop the laptop-only packages:
`tlp`, `zramen`, `earlyoom`, `iwd`, `grub`/`grub-x86_64-efi` (desktop boots with `limine` instead),
`unbound`, `cronie`, `socklog-void`, `elogind` (desktop uses `seatd` + `turnstile`).

```sh
doas xbps-install -S $(cat ~/.config/system-configs/packages-void.txt)   # start from the laptop's list
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

# desktop only: seatd + turnstile instead of elogind
for s in seatd turnstiled; do
  doas ln -s /etc/sv/$s /var/service/
done
# optional on the desktop: quick power profile switching (never alongside TLP)
# doas ln -s /etc/sv/power-profiles-daemon /var/service/
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
- [ ] consider the `fullscreenadaptivesync` dwl patch (VRR on the OLED)
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
- [ ] TRIM: `discard` mount option instead of a weekly fstrim job
- [ ] IPv4 only: `ipv6.disable=1` on the kernel command line; nftables.conf stays the same as the laptop's
- [ ] session packages to skip (autostart.sh doesn't run them on the desktop):
      `kanshi`, `gammastep`, `xsettingsd`, `polkit-gnome`, `gnome-keyring`, `cliphist`,
      `sway-audio-idle-inhibit` - keep `wl-clipboard` (screenshots), `swayidle`, `waylock`, `wlopm`, `easyeffects`
- [ ] laptop-only apps, skip on the desktop: VS Code, ProjectLibre, Vivado, `tailscale`
      - `mimeapps.list` opens code/text files with `code.desktop`: set those to `nvim.desktop` on the desktop
      - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
      - add `gnome-keyring` back if signing into VS Code/GitHub on the desktop
- [ ] optional: `power-profiles-daemon` + `powerprofilesctl set performance` for gaming
- [ ] `rc.conf` KEYMAP `us` (US keyboard only) - automatic via the `rc.conf` template
- [ ] bootloader: Limine instead of GRUB
      - kernel options: the laptop's `loglevel=4 nowatchdog mitigations=off`, plus `ipv6.disable=1` (IPv4 only)
      - check whether Void's `limine` package updates its config when the kernel updates;
        if not, add a hook in `/etc/kernel.d/post-install/` - linux-mainline updates often,
        and a stale entry means booting an old (or removed) kernel
