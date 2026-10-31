# Void Linux + dwl install checklist: desktop (`void-desktop`)

Setting up the new PC with the same Void + dwl setup as the laptop (`void`). Section 0 starts on the laptop, then
moves to the new PC for the BIOS and the backup (from the live ISO); everything after it is on the desktop.

Hardware: Ryzen 7 7800X3D, Gigabyte B850 EAGLE WIFI7 ICE, 32 GB DDR5-6000 CL30, XFX Swift RX 9070 16 GB,
Asus ROG Strix OLED XG27ACDNG (2560x1440 @ 360 Hz), ADATA 512 GB NVMe (system), WD Green 1 TB SATA SSD (games).

---

## 0. Before starting (on the laptop)

Do these first, then keep this checklist open on the laptop while installing on the PC.

Last updated: 30 Oct 2026.

### Right before the install
- [ ] refresh the package and service lists, then push:
  ```sh
  xbps-query -m > ~/.config/system-configs/packages-void.txt
  command ls /var/service > ~/.config/system-configs/services-void.txt   # 'command' skips the eza alias
  chezmoi re-add
  chezmoi git -- commit -am "Refresh package and service lists" && chezmoi git -- push
  ```
- [ ] check the Limine kernel hook is in the pushed repo - step 1 fetches it straight from GitHub
  (it should print `200`):
  ```sh
  curl -fsI https://raw.githubusercontent.com/bradleycross07/dot_files/void-linux/dot_config/system-configs/executable_60-limine | head -1
  ```
- [ ] bring dwl up to date with the main branch:
  ```sh
  cd ~/.local/src/dwl
  # switch to it, or create it the first time
  git switch desktop 2>/dev/null || git switch -c desktop
  git merge main
  git push -u origin desktop
  # back to main, or the laptop's next `make` builds the desktop config
  git switch main
  ```
- [ ] uBlock Origin: Settings → **Back up to file** (it's not in the dotfiles or Firefox Sync; saves to `~/Downloads`)
- [ ] copy the SSH key, game saves and uBlock backup onto the Ventoy USB's data partition - step 4 restores them:
  ```sh
  doas mount -o uid=1000,gid=1000 /dev/sdX1 /mnt
  mkdir -p /mnt/ssh-key /mnt/saves /mnt/backups
  cp ~/.ssh/{github-void,github-void.pub,config} /mnt/ssh-key/
  # Hollow Knight + Silksong
  tar -czf /mnt/saves/unity3d.tar.gz -C ~ .config/unity3d
  # Celeste: -h stores what the Saves link points at, so the desktop gets a normal folder
  tar -czhf /mnt/saves/celeste.tar.gz -C ~ .local/share/Celeste
  cp ~/Downloads/my-ublock-backup_*.txt /mnt/backups/
  doas umount /mnt
  ```

### BIOS / UEFI
- [ ] plug the monitor into the RX 9070, not the motherboard - its video outputs go dead once the iGPU is
  disabled below
- [ ] update the BIOS first (newest for the B850 board) - do everything below *after* the update,
  since updating resets the settings
- [ ] UEFI only: CSM off, Secure Boot off, TPM off
- [ ] disable the 7800X3D's integrated graphics (Integrated Graphics: Disabled) - the RX 9070 is the only GPU,
  so dwl can't end up compositing on the iGPU, and gamemode's `gpu_device` is unambiguous
- [ ] EXPO on for the DDR5-6000 CL30 kit - the first boot can sit on a black screen for a few
  minutes while the RAM trains
- [ ] Resizable BAR (and Above 4G Decoding) on for the RX 9070
- [ ] 7800X3D: CPPC and CPPC Preferred Cores **Enabled** (amd-pstate needs CPPC - without it Linux falls back to
  acpi-cpufreq); Global C-states left on (idle cores give the busy ones boost headroom)
- [ ] after EXPO: check UCLK runs 1:1 with the memory clock (UCLK = MCLK) and FCLK is around 2000 - usually right on Auto
- [ ] Memory Context Restore on (skips RAM retraining every boot - turn it back off if it causes memory errors)
- [ ] don't raise SoC voltage above ~1.3 V
- [ ] onboard Wi-Fi and Bluetooth off (wired only), and Gigabyte's "APP Center Download & Install" off (Windows-only)
- [ ] later, once stable: Curve Optimizer (under PBO) with a negative all-core offset - step down gradually and
  stress-test between steps

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
5. Copy what's wanted from the Windows drive (`--preserve=timestamps` instead of `-a`), e.g.
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
- SATA SSD: ext4, games (`~/Games`)

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
printf 'ignorepkg=linux-firmware-nvidia\nignorepkg=linux-firmware-intel\nignorepkg=linux-firmware-broadcom\n' \
    > /mnt/etc/xbps.d/ignore.conf
```

### Install the base system

Copy the live system's xbps signing keys first, so the new root trusts the repo, then install:

```sh
mkdir -p /mnt/var/db/xbps/keys && cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

XBPS_ARCH=x86_64 xbps-install -S -r /mnt -R https://repo-de.voidlinux.org/current \
    base-minimal linux-mainline linux-mainline-headers dracut eudev kmod \
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

Kernel hook:

```sh
mkdir -p /etc/kernel.d/post-install /etc/kernel.d/post-remove
cd /etc/kernel.d/post-install
xbps-uhelper fetch https://raw.githubusercontent.com/bradleycross07/dot_files/void-linux/dot_config/system-configs/executable_60-limine
mv executable_60-limine 60-limine && chmod +x 60-limine
# the same script on removal (it checks which folder it was run from)
ln -s ../post-install/60-limine ../post-remove/60-limine
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

The dotfiles are cloned now but applied in step 6: the package lists and mirrors are read straight from
the clone, and the repo is public, so no SSH key is needed for this:

```sh
# delta is .gitconfig's pager
doas xbps-install -S void-repo-nonfree git chezmoi delta
chezmoi init --branch void-linux https://github.com/bradleycross07/dot_files.git
# git identity + commit signing;
# cargo config: every Rust build links with mold and tunes for this CPU
chezmoi apply ~/.gitconfig ~/.cargo/config.toml
# the laptop's mirrors, for main and nonfree (written by xmirror on the laptop)
cd "$(chezmoi source-path)/dot_config/system-configs"
doas cp xbps.d/00-repository-main.conf xbps.d/10-repository-nonfree.conf /etc/xbps.d/
doas xbps-install -Su
```

Install packages by hand, one group at a time - the laptop's list (`packages-void.txt`, in the same folder) is a
reference to pick from, not something to install wholesale. Build dependencies are installed with each build in step 4.

Don't install on the desktop:
- laptop power/memory/network: `tlp`, `zramen`, `iwd`, `wifi-firmware`, `unbound`, `wireguard-tools`
- `grub-x86_64-efi` (Limine instead), `elogind` (seatd + turnstile instead), `cronie`, `socklog-void`, `yarn`
- laptop session extras (autostart.sh doesn't run them on the desktop): `kanshi`, `gammastep`,
  `xsettingsd`, `polkit-gnome`, `gnome-keyring`, `cliphist`, `sway-audio-idle-inhibit`
  - optional: `wl-clip-persist` keeps the clipboard after the source app closes (no history)
  - add `gnome-keyring` back if signing into apps that need a keyring
- laptop-only apps: VS Code, ProjectLibre, Vivado, the restricted `discord` package (Vesktop instead), and
  Spotify + Spicetify (built from `void-packages` on the laptop as a backup for spotatui)

Packages the later steps rely on (still in the `system-configs` folder, for the font lists):

```sh
doas xbps-install -S chrony nftables rtkit turnstile power-profiles-daemon
doas xbps-install -S pipewire wireplumber alsa-pipewire easyeffects pavucontrol \
    swayidle waylock wlopm wl-clipboard foot fuzzel qt6-wayland
doas xbps-install -S mesa-dri mesa-vulkan-radeon vulkan-loader
doas xbps-install -S mesa-vaapi libva-utils
doas xbps-install -S gamemode gamescope mangohud
# mouse DPI/polling rate (bradley is already in plugdev from step 1)
doas xbps-install -S openrazer-meta razergenie
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

## 4. Built from source (`~/.local/src`)

### From the Ventoy USB: SSH key, game saves

The SSH key comes first: it signs commits and pushes your rebased branches back to GitHub.

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
# uBlock Origin backup (exported in step 0), restored from Firefox in step 7
mkdir -p ~/backups && cp /mnt/backups/* ~/backups/
# once ssh -T has greeted you: the key doesn't stay on the USB
rm -r /mnt/ssh-key
doas umount /mnt
```

### Updating your changes to the latest upstream

Each repo below is cloned with your commits on top of whatever upstream version they were last based on. Rebase
them onto the newest upstream as you clone, so the install starts current. If a rebase stops on a conflict: fix the
file, `git add` it, `git rebase --continue`; if the conflicting commit is one upstream has since merged (like dwl's
lock-screen fixes), `git rebase --skip` drops it. Push the result back afterwards, as each section shows.

### Rust builds

```sh
# after `git clone ... ~/.local/src/<name>`:
chezmoi apply ~/.local/src/<name>/.cargo/config.toml
echo ".cargo/" >> ~/.local/src/<name>/.git/info/exclude
```

The binaries go in `~/.local/bin`, which `.zprofile` puts on `PATH` from step 6:

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
# onto the newest dwl release (skipped if desktop already contains it)
git fetch upstream --tags
latest=$(git tag -l 'v*' --sort=-v:refname | grep -v -- - | head -1)
git merge-base --is-ancestor "$latest" HEAD || git rebase --onto "$latest" "$(git merge-base HEAD upstream/main)"
# a new release may need a newer wlroots: check config.mk's wlroots-0.xx matches the -devel installed above
make && doas make install
git push --force-with-lease origin desktop
```
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

Proton games still on X11: try `PROTON_ENABLE_WAYLAND=1`.

### Aurelia
- build dependency: `dbus-devel` (its keyring support builds against libdbus; gcc and pkg-config came with the
  dwl step, and it uses rustls, so no openssl):
  ```sh
  doas xbps-install -S dbus-devel
  ```
- bubblewrap, for the launch scripts:
  ```sh
  doas xbps-install -S bubblewrap
  ```
- 32-bit graphics libraries for Wine/Proton games (older 32-bit games need them):
  ```sh
  doas xbps-install -S void-repo-multilib
  doas xbps-install -S mesa-dri-32bit vulkan-loader-32bit mesa-vulkan-radeon-32bit
  ```
- clone upstream, plus a `local` branch tracking `origin/main` (what `update-aurelia` switches to):
  ```sh
  git clone https://github.com/Drackrath/Aurelia.git ~/.local/src/Aurelia
  chezmoi apply ~/.local/src/Aurelia/.cargo/config.toml
  echo ".cargo/" >> ~/.local/src/Aurelia/.git/info/exclude
  cd ~/.local/src/Aurelia
  git switch -c local --track origin/main
  ```
- build, install, then clean:
  ```sh
  cargo build --release
  cp target/release/aurelia ~/.local/bin/
  cargo clean
  ```

### spotatui
- build dependencies:
  ```sh
  doas xbps-install -S rust cargo mold pkg-config alsa-lib-devel dbus-devel openssl-devel
  ```
- clone your repo (its `local` branch is the latest release plus the local patches), and add upstream
  for updates - the same remotes as on the laptop:
  ```sh
  git clone -b local git@github.com:bradleycross07/spotatui-local.git ~/.local/src/spotatui
  chezmoi apply ~/.local/src/spotatui/.cargo/config.toml
  echo ".cargo/" >> ~/.local/src/spotatui/.git/info/exclude
  cd ~/.local/src/spotatui
  git remote add upstream https://github.com/LargeModGames/spotatui.git
  git fetch upstream --tags
  # onto the newest release (skipped if the branch already contains it)
  latest=$(git tag -l 'v*' --sort=-v:refname | grep -v -- - | head -1)
  git merge-base --is-ancestor "$latest" HEAD || git rebase --onto "$latest" "$(git merge-base HEAD upstream/main)"
  ```
- build with only the features in use (`self-update` would replace the patched binary with an official
  release; the macOS/Windows media features don't build on Linux anyway), install, clean:
  ```sh
  cargo build --release --no-default-features --features tui,streaming,discord-rpc,mpris,cover-art,scripting
  cp target/release/spotatui ~/.local/bin/
  cargo clean
  git push --force-with-lease origin local
  ```

### Vesktop
- needs pnpm (standalone installer) and Node.js, which on the laptop is managed by pnpm itself
  (`pnpm ls -g` shows `node@26` as a global) rather than Void's `nodejs` package:
  ```sh
  # writes a pnpm block to ~/.zshrc - step 6 replaces that file, and the
  # dotfiles' .zprofile sets PNPM_HOME and PATH instead
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  # reload so PNPM_HOME/PATH apply
  exec zsh
  pnpm --version
  # pnpm-managed Node, same major version as the laptop
  # (see `pnpm help env` if the command has changed)
  pnpm env use --global 26
  node --version
  ```
- clone, get the raised-bitrate `local` branch from your `vesktop-local` repo, build, install into `~/.local/opt/Vesktop`:
  ```sh
  git clone https://github.com/Vencord/Vesktop.git ~/.local/src/Vesktop
  cd ~/.local/src/Vesktop
  git remote add backup git@github.com:bradleycross07/vesktop-local.git
  git fetch backup
  git switch -c local --track backup/local
  # onto the newest release (skipped if the branch already contains it)
  git fetch origin --tags
  latest=$(git tag -l 'v*' --sort=-v:refname | grep -v -- - | head -1)
  git merge-base --is-ancestor "$latest" HEAD || git rebase --onto "$latest" "$(git merge-base HEAD origin/main)"
  pnpm install --frozen-lockfile
  # unpacked build in dist/linux-unpacked
  pnpm package:dir
  rm -rf ~/.local/opt/Vesktop
  mkdir -p ~/.local/opt
  cp -r dist/linux-unpacked ~/.local/opt/Vesktop
  git push --force-with-lease backup local
  ```

### InputPlumber
- build dependencies (`libclang<N>` matches the LLVM version Mesa already uses):
  ```sh
  N=$(xbps-query -x mesa-libgallium | sed -n 's/^libllvm\([0-9]*\).*/\1/p')
  # 22 in Oct 2026 - if it's changed, bump the 22s in .cargo/config.toml first (laptop too)
  echo "$N"
  doas xbps-install -S rust cargo pkg-config eudev-libudev-devel libclang$N
  ```
- clone, add the build config, link libclang where `.cargo/config.toml` expects it, build as your user,
  install as root:
  ```sh
  git clone https://github.com/ShadowBlip/InputPlumber.git ~/.local/src/InputPlumber
  chezmoi apply ~/.local/src/InputPlumber/.cargo/config.toml
  echo ".cargo/" >> ~/.local/src/InputPlumber/.git/info/exclude
  mkdir -p ~/.local/lib/libclang
  # 'command' skips the eza alias; head -1 picks libclang.so.$N.1 over the longer full-version name
  ln -sf "$(command ls -1 /usr/lib/libclang.so.$N.* | sort | head -1)" ~/.local/lib/libclang/libclang.so
  readlink ~/.local/lib/libclang/libclang.so
  cd ~/.local/src/InputPlumber
  make build
  doas make install PREFIX=/usr
  # the install also drops systemd units, which do nothing on Void
  doas rm /usr/lib/systemd/system/inputplumber*.service
  ```
- its install adds udev rules, hwdb entries and a D-Bus system policy, which only take effect once reloaded:
  ```sh
  doas udevadm hwdb --update && doas udevadm control --reload && doas udevadm trigger
  # picks up org.shadowblip.InputPlumber.conf, so the service may claim its name
  doas sv reload dbus
  ```
- its DualSense config and runit service come from the dotfiles - restored in step 7

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

Lutris comes from Flathub, installed per-user. The flatpak export paths are added to `XDG_DATA_DIRS` by
`/etc/profile.d/flatpak.sh`, which the package installs, so the app shows up in fuzzel after the next login.

```sh
doas xbps-install -S flatpak
flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub net.lutris.Lutris org.gtk.Gtk3theme.Breeze-Dark
```

## 6. Dotfiles (chezmoi)

```sh
# the laptop-only files must show up here - if the list only has README.md and INSTALL.md,
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
a replug) and its service, then enable it. The laptop's log service uses `vlogger` (socklog), which the desktop
doesn't run, so swap it for svlogd writing to `/var/log/inputplumber`:

```sh
doas mkdir -p /etc/inputplumber/devices.d
doas cp ~/.config/system-configs/inputplumber/*.yaml /etc/inputplumber/devices.d/
doas cp -r ~/.config/system-configs/sv-inputplumber /etc/sv/inputplumber
printf '#!/bin/sh\nexec svlogd -tt /var/log/inputplumber\n' | doas tee /etc/sv/inputplumber/log/run
doas mkdir -p /var/log/inputplumber
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

- [ ] Firefox `user.js` (Betterfox + overrides), `userChrome.css` and `userContent.css` - close Firefox
  completely, then copy all three:
  ```sh
  # paste the Root Directory from about:profiles
  p=~/.config/mozilla/firefox/XXXXXXXX.default-default
  src=$(echo "$(chezmoi source-path)"/dot_config/private_mozilla/private_firefox/*)
  mkdir -p "$p/chrome"
  cp "$src"/user.js "$p/"
  cp "$src"/chrome/userChrome.css "$src"/chrome/userContent.css "$p/chrome/"
  ```
  - `user.js` already turns on `toolkit.legacyUserProfileCustomizations.stylesheets`
  - edit `user.js` for the desktop **before** the next start: delete `user_pref("media.av1.enabled", false);` -
    that's only for the laptop's GPU, the RX 9070 decodes AV1 in hardware
- [ ] uBlock Origin: Settings → **Restore from file** → the backup in `~/backups` (the settings aren't in Sync)
- [ ] Vesktop: log in to Discord (the session isn't in the dotfiles); Vencord's settings come back through its
  cloud sync

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

## 9. Screen sharing (Vesktop, Firefox, OBS)

```sh
doas xbps-install -S xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```

- [ ] the portals find the compositor because `~/.local/bin/autostart.sh` passes the session environment to
  D-Bus first thing (`rg -n dbus-update-activation-environment ~/.local/bin/autostart.sh`):
  ```sh
  dbus-update-activation-environment --all
  ```
- [ ] `~/.config/xdg-desktop-portal/portals.conf`:
  ```ini
  [preferred]
  default=gtk
  org.freedesktop.impl.portal.ScreenCast=wlr
  org.freedesktop.impl.portal.Screenshot=wlr
  ```
- [ ] `~/.config/xdg-desktop-portal-wlr/config`:
  ```ini
  [screencast]
  max_fps=60
  chooser_type=dmenu
  chooser_cmd=fuzzel --dmenu -p "Share: "
  ```

## 10. System configs (/etc)

Copies live in `~/.config/system-configs` (applied by chezmoi in step 6).

| Backup file          | Restore to                    | Notes                     |
| -------------------- | ----------------------------- | ------------------------- |
| `99-network.conf`    | `/etc/sysctl.d/`              | BBR + fq                  |
| `sysctl.conf`        | `/etc/sysctl.conf`            | `vm.max_map_count=1048576` (some Proton games need it) |
| `rc.local`           | `/etc/rc.local`               | MGLRU thrashing protection (`min_ttl_ms` 1000) - stands in for earlyoom, which isn't installed |
| `dracut.conf.d/no-drm.conf` | `/etc/dracut.conf.d/`  | leaves `drm` (amdgpu + every AMD GPU's firmware) and the crypt modules out of the initramfs - amdgpu loads from the root filesystem instead. Rebuild after copying |
| `doas.conf`          | `/etc/doas.conf`              | check with `doas -C` first; `chmod 0400`; passwordless poweroff/reboot, plus `sv up/down inputplumber` for the Aurelia launch scripts. `zzz` isn't passwordless any more - add `permit nopass bradley cmd zzz` back if suspending from a keybind |
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
| `60-limine`          | `/etc/kernel.d/post-install/` | `chmod +x`, plus a symlink to it in `post-remove/`; already in place from step 1 (fetched from the repo) - only for a future reinstall |
| `xbps.d/*.conf`      | `/etc/xbps.d/`                | mirrors restored in step 2. The pins (`ignore.conf`, `mainline.conf`) were already written in step 1, before anything was installed - nothing to restore |

```sh
cd ~/.config/system-configs
# check doas.conf and nftables.conf BEFORE copying them into /etc:
doas -C doas.conf && doas cp doas.conf /etc/doas.conf && doas chmod 0400 /etc/doas.conf
doas nft -c -f nftables.conf && doas cp nftables.conf /etc/nftables.conf
doas cp 99-network.conf /etc/sysctl.d/
doas cp sysctl.conf /etc/sysctl.conf
doas cp rc.local /etc/rc.local        # runs at the next boot
# smaller initramfs: rebuild every installed kernel's image (the Limine hook doesn't need re-running -
# the file names stay the same)
doas cp dracut.conf.d/no-drm.conf /etc/dracut.conf.d/ && doas dracut --regenerate-all --force
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

## 11. Desktop-specific

- [ ] check the dedicated GPU is the one in use: `lspci -k` (the RX 9070 with `amdgpu`)
- [ ] check the monitor is running at 360 Hz inside dwl: `doas xbps-install -S wlr-randr && wlr-randr`. dwl's
  monitor rules can't set a mode - it uses the monitor's preferred one. If that isn't 360 Hz, add the mode to
  the desktop part of `autostart.sh` (`chezmoi edit ~/.local/bin/autostart.sh`), with the output name
  `wlr-randr` printed:
  ```sh
  {{- if ne .chezmoi.hostname "void" }}
  wlr-randr --output DP-1 --mode 2560x1440@360Hz
  {{- end }}
  ```
- [ ] USB layout: put the mouse and keyboard on a different USB controller from the headset and anything
  high-traffic, ideally rear ports wired to the CPU rather than front-panel or hub ports. `lsusb -t` shows
  which bus (controller) each device is on
- [ ] machine-specific configs - they arrive with the laptop's values; edit them for this PC:
  - fastfetch (`~/.config/fastfetch/config.jsonc`): CPU line ("Ryzen 5 5500U" → 7800X3D), GPU line
    ("Lucienne" → RX 9070), memory speed ("4266 MT/s" → 6000)
  - btop (`~/.config/btop/btop.conf`): `custom_cpu_name`, `custom_gpu_name0`, `show_battery`
  - mpv (`~/.config/mpv/mpv.conf`): `gpu-api=vulkan`, heavier scalers, add `av1` to `hwdec-codecs`, and loosen
    `ytdl-format` - the laptop caps YouTube at VP9 because its decoder can't do AV1, the RX 9070 can
    (`vainfo` lists what the GPU decodes)
  - Vesktop wrapper (`~/.local/bin/vesktop`): remove the
    `--disable-features=AcceleratedVideoEncoder,VaapiVideoEncoder` line (the RX 9070 can hardware-encode)
  - once edited, add these files to the desktop block of `.chezmoiignore`, so the laptop and desktop
    versions don't overwrite each other
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
- [ ] seat management: `seatd` + `turnstile` instead of elogind
  (see https://docs.voidlinux.org/config/session-management.html)
- [ ] minimal service set - no TLP, zram, earlyoom, iwd, unbound, cronie or logging:
  ethernet only, 32 GB RAM, amd-pstate-epp handles the 7800X3D
- [ ] kernel options (in the Limine hook): `loglevel=4 nowatchdog modprobe.blacklist=sp5100_tco mitigations=off ipv6.disable=1`
  - `sp5100_tco` is AMD's chipset watchdog driver - blacklisted on the laptop too, alongside `nowatchdog`
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
  command ls /var/service > ~/.config/system-configs/services-$(hostname).txt
  chezmoi add ~/.config/system-configs/{packages,services}-$(hostname).txt
  chezmoi git -- commit -m "Desktop package and service lists" && chezmoi git -- push
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
- [ ] GTK 4: `~/.config/gtk-4.0/gtk.css` links to Breeze-Dark's, which loads its images from `../assets` - so
  that path has to exist next to it (it's no longer in the dotfiles):
  `ln -s /usr/share/themes/Breeze-Dark/assets ~/.config/assets && ls ~/.config/assets/ | head`
- [ ] gsettings - GTK apps on Wayland read these, and they live in the binary `~/.config/dconf/user`,
  which isn't in the repo. dconf saves through dwl's D-Bus session bus, so run these **in foot inside dwl** -
  from the bare tty the values silently don't save:
  ```sh
  gsettings set org.gnome.desktop.interface gtk-theme 'Breeze-Dark'
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
  gsettings set org.gnome.desktop.interface cursor-size 32
  # the interface font (Pixelify Sans), taken from the GTK settings that came with the dotfiles
  gsettings set org.gnome.desktop.interface font-name "$(sed -n 's/^gtk-font-name=//p' ~/.config/gtk-3.0/settings.ini)"
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  ```
- [ ] cursor size 32 also needs the dwl `cursorsize` patch (on the `desktop` branch after the merge in step 0) -
  `echo $XCURSOR_SIZE` inside dwl should print `32`
