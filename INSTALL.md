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
- [ ] themes: save which packages provide the GTK theme, icons, cursor and Qt styling (restored in step 6).
      `xbps-query -o` takes one pattern at a time, hence the loop:
      ```sh
      for p in '*Breeze-Dark/gtk-3.0/gtk.css' '*Papirus-Dark/index.theme' '*Bibata-Modern-Classic/index.theme' \
               '*/bin/qt6ct' '*styles/breeze6.so' '*qqc2-desktop-style*'; do
          xbps-query -o "$p" || echo "NOT FROM A PACKAGE: $p" >&2
      done | sed 's/: .*//' | xargs -n1 xbps-uhelper getpkgname | sort -u \
          > ~/.config/system-configs/themes-void.txt
      ```
      anything reported as "NOT FROM A PACKAGE" was installed by hand (e.g. Bibata in `~/.local/share/icons/`) -
      `chezmoi add` that folder instead
- [ ] gamemode: back up the system config (the `[gpu]` section is only allowed in `/etc`):
      `cp /etc/gamemode.ini ~/.config/system-configs/gamemode.ini`
- [ ] `.zshrc`: the `gh completion` line is gone (Void's `github-cli` already ships `_gh`), and the compinit
      block creates its cache directory, so the first shell on the desktop doesn't fail to write the dump:
      ```zsh
      autoload -Uz compinit
      zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-$ZSH_VERSION"
      [[ -d ${zcompdump:h} ]] || mkdir -p ${zcompdump:h}
      compinit -d "$zcompdump"
      unset zcompdump
      ```
- [ ] export the local patches of everything built from source with my own changes - they only exist as
      local commits (`patches` is listed in `.chezmoiignore`, so it stays in the repo and is never copied into `~`):
      ```sh
      cd ~/.local/src/Aurelia   && git format-patch origin/main..local  -o "$(chezmoi source-path)/patches/aurelia"
      cd ~/.local/src/spotatui  && git format-patch origin/HEAD..local  -o "$(chezmoi source-path)/patches/spotatui"
      # Vesktop (raised stream bitrate, committed on its own `local` branch)
      cd ~/.local/src/Vesktop   && git format-patch origin/main..local  -o "$(chezmoi source-path)/patches/vesktop"
      ```
      (if `origin/HEAD` doesn't exist in a clone, use the upstream branch name instead, e.g. `origin/main`)
- [ ] make sure the Vesktop desktop entry and wrapper are in chezmoi:
      `chezmoi managed | command grep -Ei 'vesktop'` should list `~/.local/share/applications/Vesktop.desktop`
      and `~/.local/bin/vesktop`
- [ ] commit + push the dotfiles (after the steps above, so the lists, patches and config changes are included).
      New files have to be added explicitly; `re-add` pulls in changes to files chezmoi already manages; the
      patches were written straight into the source repo, so `add -A` picks them up:
      ```sh
      chezmoi add ~/.config/system-configs/fonts-void.txt ~/.config/system-configs/fonts-confd.txt \
                  ~/.config/system-configs/themes-void.txt ~/.config/system-configs/gamemode.ini
      chezmoi re-add
      chezmoi diff                       # should print nothing now
      chezmoi git -- add -A
      chezmoi git -- status              # check the lists, gamemode.ini and patches/ are listed
      chezmoi git -- commit -m "Prepare for desktop install" && chezmoi git -- push
      ```
      (if `fonts-confd.txt` is empty, chezmoi may skip it - that's fine, step 3 copes with it missing)
- [ ] dwl: bring the `desktop` branch up to date with everything merged into `main` since it was created
      (e.g. `cursorsize`), then push it - step 8 clones it fresh:
      ```sh
      cd ~/.local/src/dwl
      git switch desktop 2>/dev/null || git switch -c desktop   # create it the first time
      git merge main
      git push -u origin desktop
      git switch main                                          # or the laptop's next `make` builds the desktop config
      ```
      repeat the merge + push right before the install if `main` changes again
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
The plan: free space on the SATA SSD (delete the Games folder), copy what's needed from the NVMe onto it,
install Void on the NVMe, sort the backup out from the finished PC, and only then format the SATA SSD at the very end.

1. Boot the Void live ISO on the new PC and log in as `root`
2. Find the partitions: `lsblk -f` or `fdisk -l` (the big NTFS partition on each drive). The names below are
   examples - the SATA SSD and the Ventoy USB are both `sdX` drives and either can be `sda`, so check the sizes
   before mounting anything.
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
5. Copy what's wanted from the Windows drive (`--preserve=timestamps` instead of `-a`, since NTFS can't store
   Unix owners/permissions), e.g.
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

### BIOS / UEFI
- [ ] update the BIOS first (newest for the B850 board) - do everything below *after* the update,
      since updating resets the settings
- [ ] UEFI only: CSM off, Secure Boot off, TPM off
- [ ] disable the 7800X3D's integrated graphics (Integrated Graphics: Disabled) - the RX 9070 is the only GPU,
      so dwl can't end up compositing on the iGPU, and gamemode's `gpu_device` is unambiguous
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

### Partition and mount (NVMe)

`cfdisk /dev/nvme0n1` - GPT, delete the Windows partitions, then: partition 1 = 512 MiB, type "EFI System";
partition 2 = the rest, type "Linux filesystem". The `efibootmgr --part 1` line later assumes the EFI partition is 1.

```sh
mkfs.vfat -F32 -n EFI /dev/nvme0n1p1
mkfs.ext4 -L void /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot && mount /dev/nvme0n1p1 /mnt/boot
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
`linux-base` package pulls in `linux-firmware-intel` and `linux-firmware-nvidia` on x86_64. The desktop is AMD only,
and `linux-firmware-amd` + `linux-firmware-network` cover everything it needs, including the CPU microcode.)

### Install the base system (`base-minimal`, not `base-system`)

`base-minimal` is the lean option, so everything the system needs to boot and get online is listed explicitly.

First check what `base-minimal` pulls in on the current repo - it must give you an init (`runit-void`).
`runit-void` is in the install line below anyway, so this is just to know what you're getting:

```sh
xbps-query -R --repository=https://repo-de.voidlinux.org/current -x base-minimal
xbps-query -R --repository=https://repo-de.voidlinux.org/current -x base-container
```

Copy the live system's xbps signing keys first, so the new root trusts the repo, then install:

```sh
mkdir -p /mnt/var/db/xbps/keys && cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal runit-void linux-mainline dracut eudev kmod e2fsprogs kbd ncurses iproute2 iputils \
    dhcpcd dbus opendoas zsh openssh less pciutils usbutils file acpid \
    linux-firmware-amd linux-firmware-network dosfstools seatd
```

Everything `base-system` adds on top is either listed above or deliberately skipped: `sudo` (doas instead),
`wpa_supplicant` and `iw` (wired dhcpcd only), `btrfs-progs`/`xfsprogs`/`f2fs-tools` (ext4 only), `void-artwork`,
`traceroute`, `ethtool`, `man-pages`/`mdocml`, and the plain `linux` kernel (`linux-mainline` instead). `bash` isn't
listed because zsh is the shell, but it still gets installed as a dependency of `dracut`, and `xbps-src` in step 8
needs it too.

What each extra is for: `runit-void` init and services, `linux-mainline` + `dracut` kernel and its initramfs,
`eudev` device manager (udevd - dwl, libinput and seatd need it), `kmod` loads kernel modules (`modprobe`, needed by
eudev and dracut), `openssh` SSH for GitHub (pushing, the private dwl repo, commit signing), `less` the pager git
and `man` expect, `pciutils`/`usbutils` `lspci`/`lsusb` (check the GPU and USB devices are detected), `file`
identifies file types, `acpid` handles ACPI events like the power button (no elogind to do it; check
`/etc/acpi/handler.sh` for what each button does), `e2fsprogs` checks the ext4 root at boot, `kbd` applies the
`rc.conf` keymap, `ncurses` terminal handling, `iproute2`/`iputils` (`ip`, `ping`), `dhcpcd` network, `dbus` +
`opendoas` + `zsh` for the user, `linux-firmware-amd` GPU/CPU firmware (the RX 9070 won't start without it),
`linux-firmware-network` the onboard ethernet chip's firmware, `dosfstools` checks the FAT32 EFI partition (where
Limine's kernels live), `seatd` seat management.

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

`xbps-query runit-void >/dev/null && echo "ok: runit-void installed"`

### Inside the chroot

- [ ] check `/etc/fstab` (generated above): ext4 root with `noatime`, EFI on `/boot`, and add `/tmp` as tmpfs:
      `tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0`
- [ ] set the hostname - chezmoi relies on it: `echo void-desktop > /etc/hostname`
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
      (the full one is restored in step 4), and check it before relying on it:
      ```sh
      echo 'permit persist bradley as root' > /etc/doas.conf && chmod 0400 /etc/doas.conf
      doas -C /etc/doas.conf && echo "doas.conf ok"
      ```

Still in the chroot, enable networking so the first boot is online (in a chroot, services are enabled
in `/etc/runit/runsvdir/default/`, not `/var/service/`):

```sh
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default/
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
ln -sf /etc/sv/udevd /etc/runit/runsvdir/default/          # usually already enabled by runit-void; -f avoids "File exists"
```

> Don't apply the dotfiles in the chroot - you're root there, so chezmoi would set up `/root`.
> Boot into the new system first and log in as `bradley`.

### Bootloader: Limine

Limine only reads FAT, so the kernels and initramfs live on the EFI partition itself, mounted at `/boot`.
Each kernel + initramfs is tens of MB; 512 MiB is plenty if old kernels are cleaned up (`doas vkpurge rm all`).

Inside the chroot:

```sh
xbps-install -S limine efibootmgr
mkdir -p /boot/EFI/BOOT
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Void Linux" --loader '\EFI\BOOT\BOOTX64.EFI'
```

(check the real path of `BOOTX64.EFI` with `xbps-query -f limine | grep -i efi` - copy it again whenever the
`limine` package updates. `\EFI\BOOT\BOOTX64.EFI` is also the firmware's fallback path, so the PC still boots it
even if `efibootmgr` fails in the chroot.)

Kernel update hook - rewrites `/boot/limine.conf` for each new kernel, so an update never leaves a stale entry,
and keeps the previous kernel as a second entry to fall back to if a new mainline kernel doesn't boot.
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
CMDLINE="root=UUID=$ROOT_UUID ro loglevel=4 nowatchdog mitigations=off ipv6.disable=1"
# newest other kernel that still has an initramfs, if any (fallback entry)
PREV=$(for k in boot/vmlinuz-*; do
           v=${k#boot/vmlinuz-}
           [ "$v" != "$VERSION" ] && [ -f "boot/initramfs-$v.img" ] && echo "$v"
       done | sort -V | tail -1)

entry() {
    printf '\n/Void Linux (%s)\n    protocol: linux\n    path: boot():/vmlinuz-%s\n    module_path: boot():/initramfs-%s.img\n    cmdline: %s\n' \
        "$2" "$1" "$1" "$CMDLINE"
}

{
    printf 'timeout: 3\n'
    entry "$VERSION" "$VERSION"
    [ -n "$PREV" ] && entry "$PREV" "$PREV, previous"
} > boot/limine.conf.new && mv boot/limine.conf.new boot/limine.conf
```

### Finish the chroot

With the hook in place, configure every package. This also runs dracut and the kernel hooks, so it writes the
initramfs and `limine.conf`:

```sh
xbps-reconfigure -fa
cat /boot/limine.conf      # check the entry
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

- [ ] log out and back in on tty1 - `.zprofile` is only read at login, and it sets `PATH` (`~/.local/bin`,
      `~/.cargo/bin`, `~/.spicetify`), the Wayland/Qt/SDL/Electron variables and the cursor settings

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

Don't install on the desktop:
- laptop power/memory/network: `tlp`, `zramen`, `earlyoom`, `iwd`, `wifi-firmware`, `unbound`, `wireguard-tools`
- `grub-x86_64-efi` (Limine instead), `elogind` (seatd + turnstile instead), `cronie`, `socklog-void`, `yarn`
- laptop session extras (autostart.sh doesn't run them on the desktop): `kanshi`, `wlr-randr`, `gammastep`,
  `xsettingsd`, `polkit-gnome`, `gnome-keyring`, `cliphist`, `sway-audio-idle-inhibit`
  - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
  - add `gnome-keyring` back if signing into apps that need a keyring
- laptop-only apps: VS Code, ProjectLibre, Vivado, and the restricted `discord` package (Vesktop instead)

Examples - packages the later steps rely on:

```sh
# services enabled in step 5
doas xbps-install -S chrony nftables rtkit turnstile power-profiles-daemon
# dwl session
doas xbps-install -S pipewire wireplumber alsa-pipewire easyeffects pavucontrol swayidle waylock wlopm wl-clipboard foot fuzzel
# graphics - dwl won't start without a Mesa driver (radeonsi + RADV for the RX 9070)
doas xbps-install -S mesa-dri mesa-vulkan-radeon vulkan-loader
# hardware video decoding (VA-API) - mpv's hwdec, Firefox and Vesktop video use it
doas xbps-install -S mesa-vaapi libva-utils
# gaming (set up in section 11)
doas xbps-install -S gamemode gamescope mangohud
# fonts - base-minimal has none, and foot/fuzzel fail to start without one: install the laptop's exact set
# (saved in step 0), re-enable the same fontconfig tweaks, then rebuild the font cache.
# ~/.config/fontconfig and ~/.local/share/fonts already came back with the dotfiles in step 2.
doas xbps-install -S $(cat ~/.config/system-configs/fonts-void.txt)
[ -s ~/.config/system-configs/fonts-confd.txt ] && while read -r c; do
    doas ln -sf "/usr/share/fontconfig/conf.avail/$c" /etc/fonts/conf.d/
done < ~/.config/system-configs/fonts-confd.txt    # skipped when there are no tweaks (empty or missing)
fc-cache -f
for f in monospace sans-serif serif emoji; do printf '%-11s ' "$f"; fc-match "$f"; done
# should match the laptop (fonts.conf puts Departure Mono first for both monospace AND sans-serif):
# monospace = DepartureMono Nerd Font Mono, sans-serif = DepartureMono Nerd Font Mono,
# serif = Noto Serif, emoji = Noto Color Emoji
# downloads for the update scripts and manual apps (update-obsidian)
doas xbps-install -S curl jq
# browser (uni Google Drive upload, screen share test)
doas xbps-install -S firefox
```

> Refresh the desktop's own lists once it's set up:
> `xbps-query -m > ~/.config/system-configs/packages-$(hostname).txt`
> `ls /var/service > ~/.config/system-configs/services-$(hostname).txt`

## 4. System configs (/etc)

`dhcpcd.conf` and `rc.conf` (and `~/.local/bin/autostart.sh`) are chezmoi templates (`.tmpl` in the repo):
their per-machine parts are filled in from the hostname. Edit them with `chezmoi edit` - `chezmoi re-add` skips templates.

Copies live in `~/.config/system-configs` (applied by chezmoi in step 2).

| Backup file          | Restore to                    | Notes                     |
| -------------------- | ----------------------------- | ------------------------- |
| `99-network.conf`    | `/etc/sysctl.d/`              | BBR + fq                  |
| `doas.conf`          | `/etc/doas.conf`              | check with `doas -C` first; `chmod 0400`; passwordless poweroff/reboot/zzz |
| `nftables.conf`      | `/etc/nftables.conf`          | check with `nft -c -f` first |
| `rc.conf`            | `/etc/rc.conf`                | template: KEYMAP `us`     |
| `dhcpcd.conf`        | `/etc/dhcpcd.conf`            | template: Cloudflare DNS  |
| `gamemode.ini`       | `/etc/gamemode.ini`           | after installing `gamemode`; set `gpu_device` for this PC (section 11) |
| `60-limine`          | `/etc/kernel.d/post-install/` | `chmod +x`; already in place from step 1 - only for a future reinstall |
| `xbps.d/*.conf`      | `/etc/xbps.d/`                | the pins - already in place from step 1; only for a future reinstall |

```sh
cd ~/.config/system-configs
# check doas.conf and nftables.conf BEFORE copying them into /etc:
doas -C doas.conf && doas cp doas.conf /etc/doas.conf && doas chmod 0400 /etc/doas.conf
doas nft -c -f nftables.conf && doas cp nftables.conf /etc/nftables.conf
doas cp 99-network.conf /etc/sysctl.d/
doas cp rc.conf /etc/rc.conf          # KEYMAP already filled in by chezmoi
doas cp dhcpcd.conf /etc/dhcpcd.conf   # DNS line already filled in by chezmoi
doas cp gamemode.ini /etc/gamemode.ini # then check gpu_device (section 11)
```

- [ ] once it's set up: back up the Limine hook and pins too:
      `cp /etc/kernel.d/post-install/60-limine ~/.config/system-configs/ && mkdir -p ~/.config/system-configs/xbps.d && cp /etc/xbps.d/*.conf ~/.config/system-configs/xbps.d/`
      then `chezmoi add` them

Not backed up on purpose (machine-specific): `/etc/fstab`.

## 5. Services (runit)

The list is saved as `~/.config/system-configs/services-void-desktop.txt` once it's set up.

```sh
# dbus, dhcpcd and udevd were already enabled in step 1
# seatd + turnstile instead of elogind, power-profiles-daemon for the CPU,
# acpid for the power button (no elogind to handle it)
for s in chronyd nftables rtkit seatd turnstiled power-profiles-daemon acpid; do
  doas ln -s /etc/sv/$s /var/service/
done
# inputplumber: after it's built in step 8
# then, once: doas powerprofilesctl set performance   (the choice is remembered across reboots)
```

- [ ] log out and back in on tty1, then check `echo $XDG_RUNTIME_DIR` prints `/run/user/1000` -
      dwl, PipeWire, foot and the portals all need it, so sort it before step 7. Void's turnstile manages the
      rundir by default and its PAM hook is already in `/etc/pam.d/system-login`, so it should just work. If it's
      empty, check `manage_rundir` isn't set to `no` in `/etc/turnstile/turnstiled.conf`, that `pam_turnstile.so`
      is still in `system-login`, and that `turnstiled` is running (`doas sv status turnstiled`)
- [ ] after restoring the configs in step 4: `doas sv restart dhcpcd` and `doas sysctl --system`
- [ ] only keep `agetty-tty1` and `agetty-tty2`: `doas rm /var/service/agetty-tty{3,4,5,6}`
- [ ] irqbalance, bluetoothd, NetworkManager, wpa_supplicant: leave disabled

## 6. Shell, editor and theming

```sh
doas xbps-install -S starship zoxide fzf eza bat ripgrep dust duf procs fastfetch neovim
git clone https://github.com/zdharma-continuum/zinit.git ~/.local/share/zinit/zinit.git
```

(`ripgrep` is needed because `.zshrc` aliases `grep` to `rg`)

- Neovim: lazy.nvim bootstraps itself on first launch
- dwl is started by typing `dwl` on tty1 (function in `.zshrc`)

### Theming

`.zprofile`, the GTK settings files, `qt6ct.conf` and `xsettingsd.conf` all come with the dotfiles, but the themes
themselves and the gsettings values don't:

```sh
# GTK theme, icons, cursor, qt6ct and the Breeze Qt style - exact packages saved on the laptop in step 0
doas xbps-install -S $(cat ~/.config/system-configs/themes-void.txt) qt6-wayland
# gsettings needs the schemas and the dconf backend, or the values below don't stick
doas xbps-install -S gsettings-desktop-schemas dconf
```

- [ ] `~/.config/assets` is a symlink to `/usr/share/themes/Breeze-Dark/assets` (used by the GTK 4 theme) -
      check it resolves now that Breeze-Dark is installed: `ls ~/.config/assets/ | head`
- [ ] gsettings - GTK apps on Wayland read these, and they live in the binary `~/.config/dconf/user`,
      which isn't in the repo:
      ```sh
      gsettings set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
      gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
      gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
      gsettings set org.gnome.desktop.interface cursor-size 32
      gsettings set org.gnome.desktop.interface font-name 'DepartureMono Nerd Font Mono 16.5'
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
      ```
- [ ] cursor size 32 also needs the dwl `cursorsize` patch (on the `desktop` branch after the merge in step 0) -
      after step 8, `echo $XCURSOR_SIZE` inside dwl should print `32`

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

### Screen sharing (Vesktop, Firefox, OBS)

On Wayland, apps can't capture the screen themselves. They ask **xdg-desktop-portal**, which hands the request to
a backend for the compositor; for wlroots compositors like dwl that's **xdg-desktop-portal-wlr**, which captures
the screen and streams it to the app through **PipeWire**. Nothing here needs a runit service: the portals are
started on demand by the D-Bus session bus that `dbus-run-session` gives dwl.

Needs: PipeWire running (autostart.sh), the D-Bus session bus, `XDG_RUNTIME_DIR` (turnstile - checked in step 5),
and `XDG_CURRENT_DESKTOP=wlroots`, which `.zprofile` already exports (dwl doesn't set it, and the portal picks its
backend from it).

```sh
doas xbps-install -S xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```
(`-gtk` provides the file-picker dialogs - also used by Qt apps, since qt6ct is set to `xdgdesktopportal` - and
the dark-mode setting; `-wlr` only does screen capture and screenshots)

- [ ] pass the Wayland variables to the D-Bus session, so the portals it starts can find the compositor.
      In `~/.local/bin/autostart.sh` (it's a template, so `chezmoi edit ~/.local/bin/autostart.sh`),
      outside any per-machine block and before anything else:
      ```sh
      dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
      ```
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
- [ ] test: start a screen share in Vesktop - fuzzel should pop up with the monitor name. Firefox's
      https://mozilla.github.io/webrtc-landing/gum_test.html (Screen capture) is a quick second check.
      If nothing appears, `pgrep -a xdg-desktop-portal` shows whether both portals started

Notes:
- whole-monitor sharing is the main use, but single windows can be shared too: dwl 0.9 exposes
  `ext_image_copy_capture_manager_v1`, `ext_foreign_toplevel_list_v1` and
  `ext_foreign_toplevel_image_capture_source_manager_v1` (confirmed on the laptop with
  `wayland-info | grep -E 'ext_image_copy|ext_foreign_toplevel'`, from `wayland-utils`). Whether windows show up
  in the fuzzel picker depends on the xdg-desktop-portal-wlr version - check with `xbps-query xdg-desktop-portal-wlr`
- Vesktop is used (built from source with a raised stream bitrate - section 8) for 1440p 60 fps streams with Nitro.
  Stream *audio* is still hit and miss on Linux

## 8. Built from source (`~/.local/src`)

Rust builds use mold and native CPU tuning from the command line (not `~/.cargo/config.toml`), so install mold once:

```sh
doas xbps-install -S rust cargo mold
```

### dwl
```sh
doas xbps-install -S base-devel pkg-config wlroots0.20-devel wayland-devel wayland-protocols \
    libinput-devel libxkbcommon-devel xcb-util-wm-devel xorg-server-xwayland
git clone git@github.com:bradleycross07/void-dwl-config.git ~/.local/src/dwl   # private: needs the SSH key from step 2
cd ~/.local/src/dwl
git remote add upstream https://codeberg.org/dwl/dwl.git
git checkout desktop          # merged with main and pushed in step 0
make && doas make install
```
(`base-devel` is gcc + make; `xcb-util-wm-devel` provides `xcb-icccm` for the XWayland build;
`xorg-server-xwayland` runs X11 apps and the few games that still need it - if `make` reports another missing
pkg-config module, install its `-devel` package)
- the `desktop` branch: monitor rule, no brightness keys, no Mod+v clipboard picker
- dwl runs `~/.local/bin/autostart.sh` at startup (a template): PipeWire, EasyEffects (mic for Vesktop) and swayidle
  (lock after 10 min, screen off after 15 - protects the OLED)
- quitting dwl stops everything autostart.sh started (the autostart patch kills its process group)

### Native Wayland by default

Most toolkits already pick Wayland when it's there: GTK 3/4 (Firefox, pavucontrol, EasyEffects), SDL3 and foot.
The rest is handled by `.zprofile` (from the dotfiles), which is exported before dwl starts:

```sh
export QT_QPA_PLATFORM="wayland;xcb"        # Qt apps, X11 as fallback (needs qt6-wayland - step 6)
export SDL_VIDEODRIVER=wayland,x11          # SDL2 apps: Wayland first, X11 as fallback
export ELECTRON_OZONE_PLATFORM_HINT=auto    # Electron apps: Vesktop, Obsidian, Motrix
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

There's no multilib, so no 32-bit graphics libraries. If a Wine/Proton game needs them (older 32-bit games), add them:
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
- build for the fastest binary (tuned for this CPU, linked with mold), install, then clean:
  ```sh
  RUSTFLAGS="-C target-cpu=native -C link-arg=-fuse-ld=mold" cargo build --release
  cp target/release/aurelia ~/.local/bin/
  cargo clean
  ```
  (release builds already use full optimisation; `target-cpu=native` tunes for the machine it's built on, so
  the desktop builds its own binary). `update-aurelia` from the dotfiles handles later updates.
- game library: `~/Games/Aurelia` - don't install games until the SATA SSD is formatted and mounted on `~/Games`
  (end of section 11); anything installed there before would end up on the NVMe, hidden under the mount
- launch scripts (`~/.config/Aurelia/scripts/<appid>.sh`): check they're in chezmoi, then adjust them for this
  monitor (section 11)

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
- zsh completion: `.zshrc` adds `~/.local/share/zsh/site-functions` to `fpath` for `_spotatui` - make sure that file
  came with the dotfiles, or regenerate it the way it was made on the laptop

### Vesktop
- needs Node.js (the build scripts run on it) and pnpm (standalone installer, as on the laptop):
  ```sh
  doas xbps-install -S nodejs
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  exec zsh                     # reload so PNPM_HOME/PATH apply
  pnpm --version
  chezmoi diff                 # the installer edits ~/.zshrc - if it added a second pnpm block, `chezmoi apply ~/.zshrc`
  ```
- clone, restore the raised-bitrate patch, build, install into `~/.local/opt/Vesktop`:
  ```sh
  git clone https://github.com/Vencord/Vesktop.git ~/.local/src/Vesktop
  cd ~/.local/src/Vesktop
  git checkout -b local
  git am "$(chezmoi source-path)"/patches/vesktop/*.patch
  pnpm install --frozen-lockfile
  pnpm package:dir                       # unpacked build in dist/linux-unpacked
  rm -rf ~/.local/opt/Vesktop && cp -r dist/linux-unpacked ~/.local/opt/Vesktop
  ```
- `~/.local/bin/vesktop` (wrapper) and `~/.local/share/applications/Vesktop.desktop` come with the dotfiles;
  the desktop entry's `MimeType=x-scheme-handler/discord;` plus `mimeapps.list`'s
  `x-scheme-handler/discord=Vesktop.desktop` make it open `discord://` links. Refresh the database once:
  `update-desktop-database ~/.local/share/applications`

### InputPlumber
- needs `rust cargo libevdev-devel libiio-devel dbus-devel` (as on the laptop; its README has the full list)
- clone and build per its README:
  `git clone https://github.com/ShadowBlip/InputPlumber.git ~/.local/src/InputPlumber`
- restore its service and enable it:
  `doas cp -r ~/.config/system-configs/sv-inputplumber /etc/sv/inputplumber && doas ln -s /etc/sv/inputplumber /var/service/`
  - then `doas rm -r /etc/sv/inputplumber/log` - it sends output to syslog (vlogger), which the desktop doesn't run

### void-packages (restricted: Spotify)
```sh
git clone https://github.com/void-linux/void-packages.git ~/.local/src/void-packages
cd ~/.local/src/void-packages
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
./xbps-src pkg spotify && doas xbps-install -R hostdir/binpkgs/nonfree spotify
```
- the official Spotify app is for Premium offline downloads; Spicetify (`~/.spicetify` is already on `PATH` via
  `.zprofile`, and its config comes with the dotfiles) is installed with its own installer, then `spicetify apply`

## 9. Manually installed apps (`~/.local/opt`)

Each has a small `exec` wrapper in `~/.local/bin`. The wrappers and update scripts come back with the dotfiles;
the apps themselves are downloaded fresh - run `update-obsidian` to install Obsidian, and download Motrix,
Archipelago and Lumafly into the paths below. Vesktop is built from source (section 8).

| App           | Location                         | Notes                                   |
| ------------- | -------------------------------- | --------------------------------------- |
| Obsidian      | `~/.local/opt/Obsidian`          | AppImage extracted; install/update with `update-obsidian` |
| Vesktop       | `~/.local/opt/Vesktop`           | built from `~/.local/src/Vesktop` (section 8) |
| Motrix        | `~/.local/opt/Motrix`            | AppImage extracted; wrapper runs `AppRun` |
| Archipelago   | `~/.local/opt/Archipelago`       | wrapper runs `ArchipelagoLauncher`      |
| Lumafly       | `~/.local/opt/Lumafly`           | wrapper `cd`s into the folder first     |

## 10. Personal data (never in the repo)

- [ ] game saves: restore `~/.config/unity3d` from the Ventoy USB

## 11. Desktop-specific

- [ ] GPU (RX 9070, RDNA4): Mesa + `mesa-vulkan-radeon` (installed in step 3), AMD firmware, mainline kernel -
      check with `lspci -k` that the GPU uses the `amdgpu` driver, and that it's the only GPU (iGPU disabled in the BIOS)
- [ ] dwl `desktop` branch: monitor rule for the XG27ACDNG, 2560x1440 @ 360 Hz
- [ ] machine-specific configs - they arrive with the laptop's values; edit them for this PC after step 2:
      - fastfetch (`~/.config/fastfetch/config.jsonc`): CPU line ("Ryzen 5 5500U" → 7800X3D), GPU line
        ("Lucienne" → RX 9070), memory speed ("4266 MT/s" → 6000)
      - btop (`~/.config/btop/btop.conf`): `custom_cpu_name`, `custom_gpu_name0`, `show_battery`
      - mpv (`~/.config/mpv/mpv.conf`): `gpu-api=vulkan`, heavier scalers, add `av1` to `hwdec-codecs`, and loosen
        `ytdl-format` - the laptop caps YouTube at VP9 because its decoder can't do AV1, the RX 9070 can
        (`vainfo` lists what the GPU decodes)
      - so chezmoi doesn't overwrite these with the laptop's values (or `re-add` the desktop's values back to the
        laptop): template the hardware lines on `.chezmoi.hostname`, or list the files in `.chezmoiignore`
        for `void-desktop` once they're edited
- [ ] text/code files: `mimeapps.list` opens them with `code.desktop`, which the desktop doesn't have. Point them at
      Neovim in foot instead - not `nvim.desktop`, which needs a terminal that xdg-open doesn't know about.
      Create `~/.local/share/applications/nvim-foot.desktop` (and `chezmoi add` it):
      ```ini
      [Desktop Entry]
      Name=Neovim (foot)
      Exec=foot nvim %F
      Terminal=false
      Type=Application
      Icon=nvim
      MimeType=text/plain;text/markdown;text/x-csrc;text/x-chdr;text/x-c++src;text/x-c++hdr;text/x-python;text/x-shellscript;application/json;application/xml;text/xml;application/yaml;application/x-yaml;
      NoDisplay=true
      ```
      then make `mimeapps.list` a chezmoi template so each machine gets its own editor - at the top:
      `{{- $editor := "code.desktop" -}}{{- if eq .chezmoi.hostname "void-desktop" -}}{{- $editor = "nvim-foot.desktop" -}}{{- end -}}`
      and every `=code.desktop` becomes `={{ $editor }}`
- [ ] gaming:
      - gamemode group (exists now that the package is installed): `doas usermod -aG gamemode bradley`,
        then log out and back in and check with `id | rg gamemode`
      - `/etc/gamemode.ini` (restored in step 4): `gpu_device` must be the RX 9070's card number. With the iGPU
        disabled there should only be one - check, and fix the file if it isn't `0`:
        ```sh
        ls -l /sys/class/drm/ | rg 'card[0-9] '
        lspci -D | rg -i 'vga|display'      # the PCI address in the card's link should match the RX 9070
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
      - `XDG_RUNTIME_DIR` must be set by turnstile - checked in step 5
      - poweroff/suspend: `doas poweroff`, `doas zzz` (no loginctl)
      - polkit prompts (e.g. mounting drives in Thunar) generally need elogind - use doas instead
- [ ] minimal service set - no TLP, zram, earlyoom, iwd, unbound, cronie or logging:
      ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] power: `power-profiles-daemon` set to `performance`
- [ ] DNS: Cloudflare directly via dhcpcd (no local cache/DoT); comes from the `dhcpcd.conf` template
- [ ] locate (only if you install one, e.g. `plocate`): no cron, so refresh its database by hand - `doas updatedb`
- [ ] TRIM: manual, no job and no `discard` - run every month or so:
      `doas fstrim -av` (trims every mounted filesystem that supports it and shows how much)
- [ ] IPv4 only: `ipv6.disable=1` on the kernel command line; nftables.conf stays the same as the laptop's
- [ ] kernel options (in the Limine hook): `loglevel=4 nowatchdog mitigations=off ipv6.disable=1`
- [ ] screen sharing: portals set up in section 7
- [ ] `rc.conf` KEYMAP `us` (US keyboard) - automatic via the `rc.conf` template
- [ ] optional, test before keeping: sched_ext scheduler (the `scx` package, e.g. `scx_lavd`) - compare frame
      times with MangoHud with and without it; only keep it if it measurably helps
- [ ] once the backup is safe: format the SATA SSD as ext4 and mount it for `~/Games`. `nofail` matters: Void
      drops to an emergency shell at boot if a mount in fstab fails, so without it a dead or unplugged SSD
      would stop the PC booting:
      ```sh
      doas mkfs.ext4 -L games /dev/sdXN          # check the device with lsblk first - this wipes it
      mkdir -p ~/Games
      echo "UUID=$(doas blkid -s UUID -o value /dev/sdXN) /home/bradley/Games ext4 defaults,noatime,nofail 0 2" | doas tee -a /etc/fstab
      doas mount ~/Games && doas chown bradley:bradley ~/Games
      ```
