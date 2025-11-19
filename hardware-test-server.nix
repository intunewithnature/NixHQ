# Hardware configuration for the test-server staging VPS.
# After reinstalling / repartitioning, regenerate with:
#
#   nixos-generate-config --root /tmp/mnt
#
# and update this file as needed, especially the root UUID.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  boot.initrd.availableKernelModules =
    [ "ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules        = [ ];
  boot.extraModulePackages  = [ ];

  # Root filesystem on /dev/vda2 (ext4)
  fileSystems."/" = {
    # Replace this with the real UUID from `lsblk -f` or `blkid /dev/vda2`
    device = "/dev/disk/by-uuid/a52d9f01-a4e9-4a7b-b1d1-623eaea304ac";
    fsType = "ext4";
  };

  # No separate /boot filesystem: GRUB is installed to /dev/vda,
  # using the bios_grub partition in your GPT layout.

  swapDevices = [ ];

  # DHCP everywhere is fine for a simple VPS setup.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.ens3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
