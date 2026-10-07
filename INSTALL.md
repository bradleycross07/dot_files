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
- [ ] fonts: save the laptop's font setup so the desktop gets exactly the same (restored in step 3):
      ```sh
      # every installed font package, including ones pulled in as dependencies (e.g. by libreoffice-fonts),
      # names only - the filter skips font *libraries* like fontconfig, freetype and libXft
      xbps-query -l | awk '{print $2}' | xargs -n1 xbps-uhelper getpkgname \
          | command grep -Ei '^(font-|noto-fonts|amiri-font|culmus|source-sans-pro)|fonts?(-ttf)?$' \
          | command grep -Ev '^font-(alias|util)$' > ~/.config/system-configs/fonts-void.txt
      # fontconfig tweaks enabled by hand in /etc (symlinks no package owns)
      for f in /etc/fonts/conf.d/*; do xbps-query -o "$f" >/dev/null 2>&1 || basename "$f"; done \
          > ~/.config/system-configs/fonts-confd.txt
      ```
      check the lists look right (`fonts-confd.txt` is empty right now - no system-wide tweaks - which is fine),
      and make sure `~/.config/fontconfig/fonts.conf` and `~/.local/share/fonts/` (DepartureMono Nerd Font,
      the monospace font) are in chezmoi - `chezmoi managed | command grep -E 'fontconfig|share/fonts'`
      should list both; if not: `chezmoi add ~/.config/fontconfig ~/.local/share/fonts`
- [ ] Aurelia: export the `local` branch's patches into the dotfiles repo (they only exist as local commits):
      `cd ~/.local/src/Aurelia && git format-patch origin/main..local -o "$(chezmoi source-path)/patches/aurelia"`
      (`patches` is listed in `.chezmoiignore`, so it stays in the repo and is never copied into `~`)
- [ ] commit + push the dotfiles (after the steps above, so the lists, fonts and Aurelia patches are included).
      The font lists are new files, so chezmoi has to be told about them; the refreshed package/service lists
      changed on disk, so `re-add` pulls those changes into the source; the patches were written straight into
      the source repo, so `add -A` picks them up:
      ```sh
      chezmoi add ~/.config/system-configs/fonts-void.txt ~/.config/system-configs/fonts-confd.txt
      chezmoi re-add
      chezmoi diff                       # should print nothing now
      chezmoi git -- add -A
      chezmoi git -- status              # check the refreshed lists, fonts-*.txt and patches/aurelia are listed
      chezmoi git -- commit -m "Prepare for desktop install" && chezmoi git -- push
      ```
      (if `fonts-confd.txt` is empty, chezmoi may skip it - that's fine, step 3 copes with it missing)
- [ ] dwl: commit + push `main`, then create and push the `desktop` branch now
      (step 8 checks it out from a fresh clone, so it must already be on GitHub):
      `cd ~/.local/src/dwl && git switch -c desktop && git push -u origin desktop && git switch main`
      (switch back to `main` afterwards, or the laptop's next `make` builds the desktop config)
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
2. Find the partitions: `lsblk -f` or `fdisk -l` (the big NTFS partition on each drive). The names below are examples - the SATA SSD and the Ventoy USB are both `sdX` drives and either can be `sda`, so check the sizes before mounting anything.
3. Mount both:
   ```sh
   xbps-install -Su xbps             # an older ISO's xbps must be updated before anything else installs
   xbps-install -S ntfs-3g           # live session only, for ntfsfix if needed
   mkdir -p /mnt/win /mnt/sata
   mount -t ntfs3 -o ro /dev/nvme0n1pX /mnt/win      # Windows drive, read-only: copying FROM it still works
   mount -t ntfs3 /dev/sdXN /mnt/sata                # SATA SSD, read-write
   ```
   Fast Startup is already disabled in Windows, but if the SATA mount still refuses ("dirty" volume),
   run `ntfsfix -d /dev/sdXN` and retry.
4. Delete the games from `/mnt/sata` to make room if needed
5. Copy what's wanted from the Windows drive (`--preserve=timestamps` instead of `-a`, since NTFS can't store Unix owners/permissions), e.g.
   ```sh
   mkdir -p /mnt/sata/backup
   cp -r --preserve=timestamps /mnt/win/Users/Bradley/Documents /mnt/sata/backup/   # Windows user is "Bradley"
   cp -r --preserve=timestamps /mnt/win/Xilinx /mnt/sata/backup/                    # Year 1 Vivado projects
   ```
   Also worth a look: `Pictures`, `Desktop` and `Downloads`
6. `umount /mnt/win /mnt/sata` - then carry on with section 1 (which wipes only the NVMe)
7. Once the desktop is set up: mount the SATA SSD with
   `doas mount -t ntfs3 -o uid=1000,gid=1000 /dev/sdXN /mnt` (so the files belong to you), upload the phone
   photos (~50 GB) and anything else to the uni Google Drive from Firefox, copy the rest to `~`, then
   `doas umount /mnt`. Only THEN reformat the SATA SSD as ext4 for games (last item in section 11).

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

### Partition and mount (desktop NVMe)

`cfdisk /dev/nvme0n1` - GPT, delete the Windows partitions, then: partition 1 = 512 MiB, type "EFI System";
partition 2 = the rest, type "Linux filesystem". The `efibootmgr --part 1` line later assumes the EFI partition is 1.

```sh
mkfs.vfat -F32 -n EFI /dev/nvme0n1p1
mkfs.ext4 -L void /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot && mount /dev/nvme0n1p1 /mnt/boot    # desktop: EFI at /boot (laptop: /mnt/boot/efi)
```

> The EFI partition **must** be mounted at `/mnt/boot` before installing anything. The kernel and initramfs are
> written into `/boot` during the install; if the EFI partition isn't mounted yet, they land on the ext4 root
> instead, and mounting the EFI partition over `/boot` afterwards hides them - Limine would find no kernel.

### xbps pins: do this in the live environment, BEFORE installing anything

With the new root mounted at `/mnt`:

```sh
mkdir -p /mnt/etc/xbps.d
printf 'ignorepkg=linux\nignorepkg=linux-headers\n' > /mnt/etc/xbps.d/mainline.conf
printf 'ignorepkg=linux-firmware-nvidia\nignorepkg=linux-firmware-intel\n' > /mnt/etc/xbps.d/ignore.conf
```

(`mainline.conf` keeps the plain `linux` kernel out, since `linux-mainline` replaces it. `ignore.conf` keeps the
NVIDIA and Intel firmware out for good, even if something depends on them - and something does: the kernel's
`linux-base` package pulls in `linux-firmware-intel` and `linux-firmware-nvidia` on x86_64. The desktop is AMD only, and
`linux-firmware-amd` + `linux-firmware-network` cover everything it needs, including the CPU microcode.
Only pin `linux-firmware-intel` on a machine with no Intel CPU, GPU or wifi.)

### Install the base system (`base-minimal`, not `base-system`)

`base-minimal` is the lean option, so everything the system needs to boot and get online is listed explicitly.
Copy the live system's xbps signing keys first, so the new root trusts the repo:

```sh
mkdir -p /mnt/var/db/xbps/keys && cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# desktop
XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal linux-mainline dracut eudev kmod e2fsprogs kbd ncurses iproute2 iputils \
    dhcpcd dbus opendoas zsh openssh less pciutils usbutils file acpid \
    linux-firmware-amd linux-firmware-network dosfstools seatd

# laptop (for reference)
XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal linux-mainline dracut eudev kmod e2fsprogs kbd ncurses iproute2 iputils \
    dhcpcd dbus opendoas zsh openssh less pciutils usbutils file acpid \
    linux-firmware-amd wifi-firmware iwd grub-x86_64-efi dosfstools socklog-void
```

`base-minimal` is just `base-container`, which already includes `glibc-locales`. Everything else `base-system` adds
is either listed above or deliberately skipped: `sudo` (doas instead), `wpa_supplicant` and `iw` (dhcpcd on the desktop,
iwd on the laptop), `btrfs-progs`/`xfsprogs`/`f2fs-tools` (ext4 only), `void-artwork`, `traceroute`, `ethtool`,
`man-pages`/`mdocml`, and the plain `linux` kernel (`linux-mainline` instead). `bash` isn't listed because zsh is the
shell, but it still gets installed as a dependency of `dracut`, and `xbps-src` in step 8 needs it too.

What each extra is for: `linux-mainline` + `dracut` kernel and its initramfs, `eudev` device manager (udevd - dwl, libinput and seatd need it), `kmod` loads kernel modules (`modprobe`, needed by eudev and dracut), `openssh` SSH for GitHub (pushing, the private dwl repo, commit signing), `less` the pager git and `man` expect, `pciutils`/`usbutils` `lspci`/`lsusb` (check the GPU and USB devices are detected), `file` identifies file types, `acpid` handles ACPI events like the power button (service enabled on the desktop only - on the laptop, elogind and `lid-handler.sh` already handle the lid; check `/etc/acpi/handler.sh` for what each button does), `e2fsprogs` checks the ext4 root at boot, `kbd` applies the `rc.conf` keymap, `ncurses` terminal handling, `iproute2`/`iputils` (`ip`, `ping`), `dhcpcd` network, `dbus` + `opendoas` + `zsh` for the user, `linux-firmware-amd` GPU/CPU firmware (the RX 9070 won't start without it), `linux-firmware-network` the onboard ethernet chip's firmware, `dosfstools` checks the FAT32 EFI partition (where Limine's kernels live), `seatd` seat management.

Before chrooting:
```sh
xbps-install -S xtools-minimal         # provides xgenfstab + xchroot (the live ISO usually has it already)
xgenfstab -U /mnt > /mnt/etc/fstab     # then check it inside the chroot (below)
cp /etc/resolv.conf /mnt/etc/          # DNS, so xbps-install works inside the chroot
xchroot /mnt /bin/bash                 # bash is there as a dracut dependency
```

Once inside the chroot, confirm:

`xbps-query linux >/dev/null && echo "plain linux IS installed - remove it" || echo "ok: no plain linux"`

`xbps-query -l | command grep 'linux-mainline\|^ii linux[0-9]'`

### Inside the chroot

- [ ] check `/etc/fstab` (generated above): ext4 root with `noatime`, EFI on `/boot/efi` (laptop, GRUB) or on
      `/boot` (desktop, Limine), and add `/tmp` as tmpfs:
      `tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0`
- [ ] set the hostname - chezmoi relies on it: `echo void-desktop > /etc/hostname` (laptop: `void`)
- [ ] timezone: `ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime`
- [ ] locale (glibc): uncomment `en_GB.UTF-8 UTF-8` in `/etc/default/libc-locales`, set `LANG=en_GB.UTF-8` in
      `/etc/locale.conf` (`glibc-locales` comes with `base-minimal`; `xbps-reconfigure -fa` at the end generates it)
- [ ] root password, as a way back in if `doas.conf` ever breaks: `passwd`
- [ ] user `bradley` with shell `zsh` and a password, in groups `wheel users audio video input plugdev`,
      plus `_seatd` on the desktop or `socklog` on the laptop (those groups exist because the packages were installed above):
      ```sh
      useradd -m -s /bin/zsh -G wheel,users,audio,video,input,plugdev,_seatd bradley   # desktop
      useradd -m -s /bin/zsh -G wheel,users,audio,video,input,plugdev,socklog bradley  # laptop
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
ln -sf /etc/sv/udevd /etc/runit/runsvdir/default/          # usually already enabled by runit-void; -f avoids "File exists"
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

(check the real path of `BOOTX64.EFI` with `xbps-query -f limine | grep -i efi` - copy it again whenever the `limine` package updates.
`\EFI\BOOT\BOOTX64.EFI` is also the firmware's fallback path, so the PC still boots it even if `efibootmgr` fails
in the chroot.)

Kernel update hook - rewrites `/boot/limine.conf` for each new kernel, so an update never leaves a stale entry.
Save as `/etc/kernel.d/post-install/60-limine` and `chmod +x` it (xbps skips hooks that aren't executable; the
`60-` makes it run after dracut's `20-initramfs`, so the initramfs exists first):

```sh
#!/bin/sh
# called by xbps after installing a kernel: $1 = package, $2 = version
# xbps runs kernel hooks from the target root directory, so paths are relative
# (same as Void's own dracut hook, which writes boot/initramfs-$VERSION.img)
VERSION="$2"
ROOT_UUID=$(findmnt -no UUID -T .)
# never write an unbootable entry: keep the old limine.conf if anything is missing
if [ -z "$VERSION" ] || [ -z "$ROOT_UUID" ] || [ ! -f "boot/vmlinuz-$VERSION" ]; then
    echo "60-limine: missing version, root UUID or kernel - limine.conf NOT updated" >&2
    exit 1
fi
cat > boot/limine.conf <<CONF
timeout: 3

/Void Linux ($VERSION)
    protocol: linux
    path: boot():/vmlinuz-$VERSION
    module_path: boot():/initramfs-$VERSION.img
    cmdline: root=UUID=$ROOT_UUID ro loglevel=4 nowatchdog mitigations=off ipv6.disable=1
CONF
```

### Laptop bootloader: GRUB (for reference)

```sh
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
```
(`/etc/default/grub` is restored from the backup in step 4)

### Finish the chroot (both machines)

With the hook in place (desktop) or GRUB installed (laptop), configure every package. This also runs dracut
and the kernel hooks, so it writes the initramfs and `limine.conf`:

```sh
xbps-reconfigure -fa
cat /boot/limine.conf      # desktop: check the entry
ls /boot                   # vmlinuz-<version> and initramfs-<version>.img must both be there
```

If `limine.conf` is missing, run the hook by hand - from `/`, since it uses relative paths:

```sh
cd / && /etc/kernel.d/post-install/60-limine linux-mainline "$(ls /boot | sed -n 's/^vmlinuz-//p' | sort -V | tail -1)"
```

### Remove leftover Windows boot entries

Wiping the NVMe removes Windows Boot Manager's files, but the firmware can keep its menu entry:

```sh
efibootmgr                     # list entries
efibootmgr -b 0001 -B          # delete one by its number (e.g. Boot0001 "Windows Boot Manager")
```

### Leave the chroot and reboot

```sh
exit                           # leave the chroot
umount -R /mnt
reboot                         # pull the Ventoy USB out once the screen goes blank
```

## 2. First boot: dotfiles (chezmoi)

Log in as `bradley` on tty1 (dhcpcd from step 1 should already have you online - check with `ping -c 3 voidlinux.org`).
zsh may show its first-run setup menu because there's no `~/.zshrc` yet - press `q` to skip it (chezmoi brings the real one). Then:

```sh
doas xbps-install -S chezmoi git
chezmoi init --branch void-linux --apply https://github.com/bradleycross07/dot_files.git
```

> The applied `.zshrc` expects its tools - until step 6 is done, new shells will print errors. They're harmless;
> finish this step, then do step 6 before steps 3-5 if they get annoying.

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
doas xbps-install -S pipewire wireplumber alsa-pipewire easyeffects pavucontrol swayidle waylock wlopm wl-clipboard foot fuzzel
# graphics - dwl won't start without a Mesa driver (desktop: radeonsi + RADV for the RX 9070)
doas xbps-install -S mesa-dri mesa-vulkan-radeon vulkan-loader
# hardware video decoding (VA-API) - mpv's hwdec, Firefox and Discord video use it
doas xbps-install -S mesa-vaapi
# fonts - base-minimal has none, and foot/fuzzel fail to start without one: install the laptop's exact set
# (saved in step 0), re-enable the same fontconfig tweaks, then rebuild the font cache.
# ~/.config/fontconfig and ~/.local/share/fonts already came back with the dotfiles in step 2.
doas xbps-install -S $(cat ~/.config/system-configs/fonts-void.txt)
[ -s ~/.config/system-configs/fonts-confd.txt ] && while read -r c; do
    doas ln -sf "/usr/share/fontconfig/conf.avail/$c" /etc/fonts/conf.d/
done < ~/.config/system-configs/fonts-confd.txt    # skipped when there are no tweaks (empty or missing)
fc-cache -f
for f in monospace sans-serif serif emoji; do printf '%-11s ' "$f"; fc-match "$f"; done
# should match the laptop: monospace = DepartureMono Nerd Font Mono (from ~/.local/share/fonts),
# sans-serif = Noto Sans, serif = Noto Serif, emoji = Noto Color Emoji
# downloads for the update scripts and manual apps (update-obsidian, update-vscode)
doas xbps-install -S curl jq
# browser (uni Google Drive upload, screen share test)
doas xbps-install -S firefox
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
| `60-limine`          | `/etc/kernel.d/post-install/` | desktop only; `chmod +x`; already in place from step 1 - only for a future reinstall |
| `xbps.d/*.conf`      | `/etc/xbps.d/`                | the pins - already in place from step 1; only for a future reinstall |

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

# desktop only: seatd + turnstile instead of elogind, power-profiles-daemon instead of TLP,
# acpid for the power button (no elogind to handle it)
for s in seatd turnstiled power-profiles-daemon acpid; do
  doas ln -s /etc/sv/$s /var/service/
done
# then, once: doas powerprofilesctl set performance   (no polkit agent without elogind; the choice is remembered across reboots)
```

- [ ] desktop: log out and back in on tty1, then check `echo $XDG_RUNTIME_DIR` prints `/run/user/1000` -
      dwl, PipeWire, foot and the portals all need it, so sort it before step 7. Void's turnstile manages the
      rundir by default and its PAM hook is already in `/etc/pam.d/system-login`, so it should just work. If it's
      empty, check `manage_rundir` isn't set to `no` in `/etc/turnstile/turnstiled.conf`, that `pam_turnstile.so`
      is still in `system-login`, and that `turnstiled` is running (`doas sv status turnstiled`)

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

## 7. Audio and screen sharing

> Do the installs and config edits here now, but the checks that need a running session (picking default
> devices, the screen share test) only work once dwl is built in step 8 - come back to them then.

### Audio

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
- [ ] laptop: set built-in speakers profile to Off if not wanted

### Screen sharing (Discord, Firefox, OBS)

On Wayland, apps can't capture the screen themselves. They ask **xdg-desktop-portal**, which hands the request to
a backend for the compositor; for wlroots compositors like dwl that's **xdg-desktop-portal-wlr**, which captures
the screen and streams it to the app through **PipeWire**. Nothing here needs a runit service: the portals are
started on demand by the D-Bus session bus that `dbus-run-session` gives dwl.

Needs: PipeWire running (autostart.sh), the D-Bus session bus, and `XDG_RUNTIME_DIR` (turnstile on the desktop,
elogind on the laptop - checked in step 5).

```sh
doas xbps-install -S xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```
(`-gtk` provides the file-picker dialogs; `-wlr` only does screen capture and screenshots)

- [ ] tell the portals which desktop this is - dwl doesn't set `XDG_CURRENT_DESKTOP`, and the portal picks its
      backend from it. In the `dwl` function in `.zshrc`, before dwl starts:
      ```sh
      export XDG_CURRENT_DESKTOP=wlroots
      ```
- [ ] pass the Wayland variables to the D-Bus session, so the portals it starts can find the compositor.
      In `~/.local/bin/autostart.sh` (both machines; it's a template, so `chezmoi edit ~/.local/bin/autostart.sh`),
      outside any per-machine block and before anything else:
      ```sh
      dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
      ```
- [ ] choose which backend handles what - `~/.config/xdg-desktop-portal/portals.conf`:
      ```ini
      [preferred]
      default=gtk
      org.freedesktop.impl.portal.ScreenCast=wlr
      org.freedesktop.impl.portal.Screenshot=wlr
      ```
- [ ] pick the monitor with fuzzel instead of the default (`slurp`, not installed) -
      `~/.config/xdg-desktop-portal-wlr/config`:
      ```ini
      [screencast]
      chooser_type=dmenu
      chooser_cmd=fuzzel --dmenu
      max_fps=60
      ```
      (desktop: `max_fps` caps the stream, not the monitor - leave it at 60, since Discord can't send 360 Hz anyway)
- [ ] add both config files to chezmoi: `chezmoi add ~/.config/xdg-desktop-portal ~/.config/xdg-desktop-portal-wlr`
- [ ] test: start a screen share in Discord - fuzzel should pop up with the monitor name. Firefox's
      https://mozilla.github.io/webrtc-landing/gum_test.html (Screen capture) is a quick second check.
      If nothing appears, `pgrep -a xdg-desktop-portal` shows whether both portals started

Notes:
- whole-monitor sharing is the main use, but single windows can be shared too: dwl 0.9 exposes
  `ext_image_copy_capture_manager_v1`, `ext_foreign_toplevel_list_v1` and
  `ext_foreign_toplevel_image_capture_source_manager_v1` (confirmed on the laptop with
  `wayland-info | grep -E 'ext_image_copy|ext_foreign_toplevel'`, from `wayland-utils`). Whether windows show up
  in the fuzzel picker depends on the xdg-desktop-portal-wlr version - check with `xbps-query xdg-desktop-portal-wlr`
- the official Discord client (Nitro) is used on purpose: it streams 1440p 60 fps, where Vesktop topped out at
  1080p 30 fps in testing and used more memory. Stream *audio* is still hit and miss on Linux

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

### Native Wayland by default

Most toolkits already pick Wayland when it's there: GTK 3/4 (Firefox, pavucontrol, EasyEffects), SDL3 and foot.
Two need telling - in the `dwl` function in `.zshrc`, next to `XDG_CURRENT_DESKTOP`, before dwl starts:

```sh
export QT_QPA_PLATFORM="wayland;xcb"            # Qt apps, X11 as fallback (needs qt6-wayland / qt5-wayland
                                                # for any Qt app you use; the vivado wrapper still forces xcb)
export ELECTRON_OZONE_PLATFORM_HINT=auto        # Electron apps: Discord, Obsidian, Motrix, VS Code
```
(newer Electron versions pick Wayland on their own and ignore the second variable, so it's harmless either way)

Don't set `SDL_VIDEODRIVER` globally: games often bundle their own SDL2, and versions older than 2.0.22 don't
understand a fallback list like `wayland,x11` - they'd fail to open a window. If a particular SDL2 game runs
on XWayland and you want it native, set it for that game only: `SDL_VIDEODRIVER=wayland <game>`.

Firefox and foot are native Wayland already. Check what's still on XWayland with `xlsclients` (from the
`xlsclients` package) while things are running - anything it lists is an X11 client.

Hollow Knight and Silksong (native Linux builds via Aurelia) already run on Wayland. Keep XWayland built into dwl
anyway for the few Wine/Proton games that still need X11 - it costs nothing when nothing's using it. For those,
Wine's Wayland driver is the way to try native Wayland first: `PROTON_ENABLE_WAYLAND=1` on GE-Proton, or for
plain Wine, unset `DISPLAY` for that game so Wine picks its Wayland driver. Not every game works with it yet,
so treat it as per-game.

The laptop dropped multilib, so there are no 32-bit graphics libraries. If a Wine/Proton game needs them (older
32-bit games), add them on the desktop:
`doas xbps-install -S void-repo-multilib && doas xbps-install -S mesa-dri-32bit vulkan-loader-32bit mesa-vulkan-radeon-32bit`

### Aurelia
- needs `rust cargo mold` (and possibly `openssl-devel` - it's on the laptop's list)
- clone it, then restore the local tweaks from the dotfiles repo onto a `local` branch
  (if `git am` stops on a conflict because upstream changed, fix the file, `git add` it, then `git am --continue`):
  ```sh
  git clone https://github.com/Drackrath/Aurelia.git ~/.local/src/Aurelia
  cd ~/.local/src/Aurelia
  git checkout -b local
  git am "$(chezmoi source-path)"/patches/aurelia/*.patch
  ```
- build for the fastest binary (full speed optimisation, tuned for this CPU, linked with mold), install, then clean:
  ```sh
  CARGO_PROFILE_RELEASE_OPT_LEVEL=3 \
  RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold" \
  cargo build --release
  cp target/release/aurelia ~/.local/bin/
  cargo clean
  ```
  `target-cpu=native` tunes for the machine it's built on, so each machine builds its own.
  `update-aurelia` from the dotfiles handles later updates.
- game library: `~/Games/Aurelia` - don't install games until the SATA SSD is formatted and mounted on `~/Games`
  (end of section 11); anything installed there before would end up on the NVMe, hidden under the mount

### InputPlumber
- needs `rust cargo libevdev-devel libiio-devel dbus-devel` (as on the laptop; its README has the full list)
- build per its README
- restore its service and enable it:
  `doas cp -r ~/.config/system-configs/sv-inputplumber /etc/sv/inputplumber && doas ln -s /etc/sv/inputplumber /var/service/`
  - desktop: then `doas rm -r /etc/sv/inputplumber/log` - it sends output to syslog (vlogger), which the desktop doesn't run

### void-packages (restricted: Discord, Spotify)
```sh
git clone https://github.com/void-linux/void-packages.git ~/.local/src/void-packages
cd ~/.local/src/void-packages
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
./xbps-src pkg discord && doas xbps-install -R hostdir/binpkgs/nonfree discord
./xbps-src pkg spotify && doas xbps-install -R hostdir/binpkgs/nonfree spotify
```

## 9. Manually installed apps (`~/.local/opt`)

Each has a small `exec` wrapper in `~/.local/bin` (VS Code is a symlink to its own `bin/code` instead). The wrappers
and update scripts come back with the dotfiles; the apps themselves are downloaded fresh - run `update-obsidian`
and `update-vscode` to install those two, and download Motrix, Archipelago and Lumafly into the paths below.

| App           | Location                         | Notes                                   |
| ------------- | -------------------------------- | --------------------------------------- |
| Obsidian      | `~/.local/opt/Obsidian`          | AppImage extracted; install/update with `update-obsidian` |
| Motrix        | `~/.local/opt/Motrix`            | AppImage extracted; wrapper runs `AppRun` |
| VS Code       | `~/.local/opt/VSCode-linux-x64`  | install/update with `update-vscode` (laptop only) |
| Archipelago   | `~/.local/opt/Archipelago`       | wrapper runs `ArchipelagoLauncher`      |
| Lumafly       | `~/.local/opt/Lumafly`           | wrapper `cd`s into the folder first     |
| ProjectLibre  | `/usr/share/projectlibre`        | jar; icon in hicolor 128x128 (laptop only) |
| Vivado 2023.2 | `/tools/Xilinx`                  | ML Standard, Zynq-7000; launch via `~/.local/bin/vivado` (laptop only) |

Laptop only - after installing Vivado, fix the folders its installer makes world-writable:
```sh
chmod 755 ~/.config/autostart ~/.config/menus
```

## 10. Secrets and personal setup (never in the repo)

- [ ] laptop only - WireGuard: restore `windscribe.conf` to `/etc/wireguard/` (or download a fresh one from Windscribe), install `wireguard-tools` (`vpnup` / `vpndown`)
- [ ] laptop only - eduroam: run the university CAT installer
- [ ] game saves: restore `~/.config/unity3d` from the Ventoy USB

## 11. Desktop-specific (void-desktop)

- [ ] GPU (RX 9070, RDNA4): Mesa + `mesa-vulkan-radeon` (installed in step 3), AMD firmware, mainline kernel -
      check with `lspci -k` that the GPU uses the `amdgpu` driver
- [ ] dwl `desktop` branch: monitor rule for the XG27ACDNG, 2560x1440 @ 360 Hz
- [ ] mpv: `gpu-api=vulkan`, heavier scalers, add `av1` to `hwdec-codecs` (needs `mesa-vaapi` from step 3;
      `vainfo` from `libva-utils` lists what the GPU can decode)
- [ ] minimal service set - no TLP, zram, earlyoom, iwd, unbound, cronie or logging:
      ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] seat management: `seatd` + `turnstile` instead of elogind
      (see https://docs.voidlinux.org/config/session-management.html)
      - don't run elogind and seatd together
      - `XDG_RUNTIME_DIR` must be set by turnstile - checked in step 5
      - poweroff/suspend: `doas poweroff`, `doas zzz` (no loginctl)
      - polkit prompts (e.g. mounting drives in Thunar) generally need elogind - use doas instead
- [ ] DNS: Cloudflare directly via dhcpcd (no local cache/DoT); comes from the `dhcpcd.conf` template
- [ ] locate (only if you install one, e.g. `plocate`): no cron, so refresh its database by hand - `doas updatedb`
- [ ] TRIM: manual, no job and no `discard` - run every month or so:
      `doas fstrim -av` (trims every mounted filesystem that supports it and shows how much)
- [ ] IPv4 only: `ipv6.disable=1` on the kernel command line; nftables.conf stays the same as the laptop's
- [ ] screen sharing: portals set up in section 7 (same config on both machines)
- [ ] session packages to skip (autostart.sh doesn't run them on the desktop):
      `kanshi`, `gammastep`, `xsettingsd`, `polkit-gnome`, `gnome-keyring`, `cliphist`,
      `sway-audio-idle-inhibit` - keep `wl-clipboard` (screenshots), `swayidle`, `waylock`, `wlopm`, `easyeffects`
      - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
      - add `gnome-keyring` back if signing into VS Code/GitHub on the desktop
- [ ] laptop-only apps, skip on the desktop: VS Code, ProjectLibre, Vivado
      - `mimeapps.list` opens code/text files with `code.desktop`: set those to `nvim.desktop` on the desktop
- [ ] power: `power-profiles-daemon` set to `performance` (never run it alongside TLP)
- [ ] optional, test before keeping: sched_ext scheduler (the `scx` package, as on the laptop, e.g. `scx_lavd`) - compare frame
      times with MangoHud with and without it; only keep it if it measurably helps
- [ ] `rc.conf` KEYMAP `us` (US keyboard only) - automatic via the `rc.conf` template
- [ ] bootloader: Limine instead of GRUB - full steps in section 1 (EFI at `/boot`, kernel hook)
      - kernel options: the laptop's `loglevel=4 nowatchdog mitigations=off`, plus `ipv6.disable=1` (IPv4 only)
- [ ] once the backup is safe: format the SATA SSD as ext4 and mount it for `~/Games`:
      ```sh
      doas mkfs.ext4 -L games /dev/sdXN          # check the device with lsblk first - this wipes it
      mkdir -p ~/Games
      echo "UUID=$(doas blkid -s UUID -o value /dev/sdXN) /home/bradley/Games ext4 defaults,noatime 0 2" | doas tee -a /etc/fstab
      doas mount ~/Games && doas chown bradley:bradley ~/Games
      ```
