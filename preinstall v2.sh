#!/usr/bin/env bash
#-------------------------------------------------------------------------
#      _          _    __  __      _   _
#     /_\  _ _ __| |_ |  \/  |__ _| |_(_)__
#    / _ \| '_/ _| ' \| |\/| / _` |  _| / _|
#   /_/ \_\_| \__|_||_|_|  |_\__,_|\__|_\__|
#  Arch Linux Post Install Setup and Config
#-------------------------------------------------------------------------

echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download - AT Only"
echo "-------------------------------------------------"
timedatectl set-ntp true
pacman -Sy --noconfirm
pacman -S --noconfirm pacman-contrib



echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk
echo "Please enter disk: (example /dev/sda)"
read DISK
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+200M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
sgdisk -n 2:0:+100G ${DISK} # partition 2 (Root), default start, remaining
sgdisk -n 3:0:-8G ${DISK}   # partition 3 (home), default start, remaining (-8G for 8GB Swap)
sgdisk -n 4:0:0 ${DISK}     # partition 4 (swap), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK} #EFI
sgdisk -t 2:8300 ${DISK} #Linux Filesystem
sgdisk -t 3:8300 ${DISK} #Linux Filesystem
sgdisk -t 4:8200 ${DISK} #Linux Swap

# label partitions
sgdisk -c 1:"EFI"  ${DISK}
sgdisk -c 2:"ROOT" ${DISK}
sgdisk -c 3:"HOME" ${DISK}
sgdisk -c 4:"SWAP" ${DISK}

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"

mkfs.vfat -F32 -n "EFI" "${DISK}1"  # Formats EFI Partition
mkfs.btrfs -L "ROOT" "${DISK}2"     # Formats ROOT Partition
mkfs.btrfs -L "HOME" "${DISK}3"     # Formats HOME Partition
mkswap "${DISK}4"                     # Create SWAP

# mount target
mkdir /mnt
mount "${DISK}2" /mnt
btrfs su cr /mnt/@          # Setup Subvolume for btrfs and timeshift
umount -l /mnt
mount "${DISK}3" /mnt       
btrfs su cr /mnt/@home      # Setup Subvolume for btrfs and timeshift
umount -l /mnt
mount -o subvol=@ "${DISK}2" /mnt        # Mount Subolume from root   
mount -o subvol=@home "${DISK}3" /mnt/   # Mount Subolume from home 
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot               # Mounts UEFI Partition

echo "--------------------------------------"
echo "-- Arch Install on selected Drive   --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware grub efibootmgr nano sudo --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt << EOT | 
echo "--------------------------------------"
echo "-- Grub Installation  --"
echo "--------------------------------------"

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "--------------------------------------"
echo "--          Network Setup           --"
echo "--------------------------------------"
pacman -S networkmanager dhclient --noconfirm --needed
systemctl enable --now NetworkManager

echo "--------------------------------------"
echo "--      Set Password for Root       --"
echo "--------------------------------------"
echo "Enter password for root user: "
passwd root

exit
umount -R /mnt

echo "--------------------------------------"
echo "--   SYSTEM READY FOR FIRST BOOT    --"
echo "--------------------------------------"
EOT