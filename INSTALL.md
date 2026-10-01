# Void Linux + dwl install checklist

Rebuilding this setup on a fresh machine. Hostnames: laptop is `void`, desktop is `void-desktop`
(see `.chezmoiignore` for what each machine skips).

Repos:
- dotfiles: `github.com/bradleycross07/dot_files` (branch `void-linux`)
- dwl: `github.com/bradleycross07/void-dwl-config` (private; upstream is Codeberg dwl)

---

## 1. Base install

Manual chroot install following https://docs.voidlinux.org (glibc, x86_64).

- [ ] ext4 root mounted with `noatime`, EFI on `/boot/efi`, `/tmp` as tmpfs (`defaults,nosuid,nodev`)
- [ ] set the hostname (`void` or `void-desktop`) - chezmoi relies on it
- [ ] user `bradley` in groups: `wheel users audio video input plugdev socklog`
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

- [ ] SSH key for GitHub + commit signing: `~/.ssh/github-void` (referenced in `.gitconfig`)
- [ ] `gh auth login` (token stays local, never commit `~/.config/gh`)
- [ ] switch the chezmoi remote to SSH if pushing from this machine

## 3. Repositories and packages

```sh
doas xbps-install -S void-repo-nonfree
doas xbps-install -Su
```

The xbps pins were already created in step 1; the copies in `~/.config/system-configs` are the backup.

Install everything from the saved list. Review it first - on the desktop drop the laptop-only packages:
`tlp`, `zramen`, `earlyoom`, `iwd`, `grub`/`grub-x86_64-efi` (desktop boots with `limine` instead).

```sh
doas xbps-install -S $(cat ~/.config/system-configs/packages.txt)
```

> Keep the list current on the old machine with: `xbps-query -m > ~/.config/system-configs/packages.txt`

## 4. System configs (/etc)

Copies live in `~/.config/system-configs` (applied by chezmoi in step 2).

| Backup file          | Restore to                    | Notes                     |
| -------------------- | ----------------------------- | ------------------------- |
| `99-core.conf`       | `/etc/sysctl.d/`              |                           |
| `99-network.conf`    | `/etc/sysctl.d/`              | BBR + fq                  |
| `99-vm.conf`         | `/etc/sysctl.d/`              | zram-tuned, laptop only   |
| `doas.conf`          | `/etc/doas.conf`              | `chmod 0400` afterwards   |
| `grub`               | `/etc/default/grub`           | laptop only; `doas update-grub` |
| `iwd-main.conf`      | `/etc/iwd/main.conf`          | laptop only (wifi)        |
| `nftables.conf`      | `/etc/nftables.conf`          | check: `nft -c -f`        |
| `rc.conf`            | `/etc/rc.conf`                | KEYMAP: `uk` laptop, `us` desktop |
| `tlp.conf`           | `/etc/tlp.conf`               | laptop only               |
| `unbound.conf`       | `/etc/unbound/unbound.conf`   | check: `unbound-checkconf`|
| `zramen.conf`        | `/etc/sv/zramen/conf`         | laptop only               |
| `dhcpcd.conf`        | `/etc/dhcpcd.conf`            | points DNS at unbound     |

```sh
cd ~/.config/system-configs
# both machines:
doas cp 99-core.conf 99-network.conf /etc/sysctl.d/
doas cp doas.conf /etc/doas.conf && doas chmod 0400 /etc/doas.conf
doas cp nftables.conf /etc/nftables.conf && doas nft -c -f /etc/nftables.conf
doas cp rc.conf /etc/rc.conf          # then set KEYMAP for this machine
doas cp unbound.conf /etc/unbound/unbound.conf && doas unbound-checkconf
doas cp dhcpcd.conf /etc/dhcpcd.conf
# laptop only (chezmoi doesn't even place these files on the desktop):
doas cp 99-vm.conf /etc/sysctl.d/
doas cp grub /etc/default/grub && doas update-grub
doas cp iwd-main.conf /etc/iwd/main.conf
doas cp zramen.conf /etc/sv/zramen/conf
doas cp tlp.conf /etc/tlp.conf
```

Not backed up on purpose (machine-specific or secret): `/etc/fstab`, `/etc/wireguard/`, `/var/lib/iwd/`.

## 5. Services (runit)

Full list saved in `~/.config/system-configs/services.txt`. Enable with:

```sh
# both machines:
for s in dbus elogind udevd dhcpcd unbound chronyd nftables cronie rtkit \
         socklog-unix nanoklogd inputplumber tailscaled; do
  doas ln -s /etc/sv/$s /var/service/
done
# laptop only:
for s in iwd tlp zramen earlyoom; do
  doas ln -s /etc/sv/$s /var/service/
done
# desktop, optional: quick power profile switching (never alongside TLP)
# doas ln -s /etc/sv/power-profiles-daemon /var/service/
```

- [ ] tailscaled: manual start only - `doas touch /etc/sv/tailscaled/down`
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
- desktop: use the `desktop` branch (monitor rule, no brightness keys)
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
| VS Code       | `~/.local/opt/VSCode-linux-x64`  | install/update with `update-vscode`     |
| Archipelago   | `~/.local/opt/Archipelago`       | wrapper in `~/.local/bin`               |
| Lumafly       | `~/.local/share/lumafly`         | wrapper in `~/.local/bin`               |
| ProjectLibre  | `/usr/share/projectlibre`        | jar; icon in hicolor 128x128            |
| Vivado 2023.2 | `/tools/Xilinx`                  | ML Standard, Zynq-7000; launch via `~/.local/bin/vivado` |

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
- [ ] no TLP, zram, earlyoom or iwd: ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] optional: `power-profiles-daemon` + `powerprofilesctl set performance` for gaming
- [ ] `rc.conf` KEYMAP `us` (US keyboard only)
- [ ] bootloader: Limine instead of GRUB
      - carry over the kernel options from the laptop's `grub` file: `loglevel=4 nowatchdog mitigations=off`
      - check whether Void's `limine` package updates its config when the kernel updates;
        if not, add a hook in `/etc/kernel.d/post-install/` - linux-mainline updates often,
        and a stale entry means booting an old (or removed) kernel
