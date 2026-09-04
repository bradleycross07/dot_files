{ config, pkgs, nixpkgs-unstable, ... }:

{
  # latest kernel (7.2.2 as of writing)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # allow pstate, mitigations off for the extra performance
  boot.kernelParams = [
    "amd_pstate=active"
    "mitigations=off"
  ];
  
  # optimsied the RAM
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.vfs_cache_pressure" = 50;
  };
  
  # allow systemd-boot to manage UEFI NVRAM boot entries directly & don't need GRUB since no dual-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
 
  boot.extraModprobeConfig = ''
    options ttm pages_limit=2097152
    options ttm page_pool_size=1048576
  '';

  # filesystems
  fileSystems."/".options = [ "compress=zstd:3" "noatime" ];
  fileSystems."/home".options = [ "compress=zstd:3" "noatime" ];
  fileSystems."/nix".options = [ "compress=zstd:3" "noatime" ];
  fileSystems."/var/log".options = [ "compress=zstd:3" "noatime" ];
  fileSystems."/boot".options = [ "umask=0077" ];
  fileSystems."/games" = {
	device = "/dev/disk/by-uuid/9a47d749-9248-4be0-a850-b8adc9320d0b";
  	fsType = "btrfs";
  	options = [ "subvol=@games" "compress=zstd:3" "noatime" "exec" ];
  };

  # hardware, microcode for security (perhaps performance)
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  
  # neeed for steam games & any other 32 bit things
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # bluetooth (disabled for now)
  hardware.bluetooth.enable = false;

  # udev rules, turned off volume control on headset, ds5 has libusb access for controller emulation
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{name}=="Kingston HyperX Cloud Stinger Wireless Consumer Control", ENV{LIBINPUT_IGNORE_DEVICE}="1"

    SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666", TAG+="uaccess"

    SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0666", TAG+="uaccess"
  '';
}
