#!/bin/bash

# CONFIGURE THESE VARIABLES!
DISK="/dev/nvme0n1"          # Replace with your target disk (e.g., /dev/nvme0n1)
HOSTNAME="onelove"
USERNAME="sum"
PASSWORD="kali"
TIMEZONE="Asia/Kolkata"   # e.g., Asia/Kolkata

EFI="/dev/nvme0n1p1"
CRYPT="/dev/nvme0n1px"

# LUKS encryption
echo -n "$PASSWORD" | cryptsetup luksFormat $CRYPT -
echo -n "$PASSWORD" | cryptsetup open $CRYPT cryptlvm -

# Set up LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 50G vg0 -n root
lvcreate -l 100%FREE vg0 -n home

# Format and mount
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home

mount /dev/vg0/root /mnt
mkdir /mnt/home /mnt/boot
mount /dev/vg0/home /mnt/home
mount $EFI /mnt/boot

# Install base system
pacstrap /mnt base linux linux-firmware lvm2 sudo networkmanager vim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot to configure system
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root and user
echo -e "$PASSWORD\n$PASSWORD" | passwd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Enable services
systemctl enable NetworkManager

# Initramfs: enable encrypt+lvm
sed -i 's/^HOOKS=(base udev autodetect.*)/HOOKS=(base udev keyboard keymap encrypt lvm2 filesystems)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Bootloader setup
bootctl install

UUID=\$(blkid -s UUID -o value $CRYPT)

cat <<LOADER > /boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
LOADER

cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux (LUKS + LVM)
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=UUID=\$UUID:cryptlvm root=/dev/vg0/root rw
ENTRY
EOF

echo "All done! You can now reboot into your encrypted LVM setup."

