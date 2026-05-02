#!/bin/bash

set -e

echo "=============================="
echo " ARCH HYPRLAND DUAL BOOT INSTALLER (SAFE FIXED VERSION)"
echo "=============================="

lsblk

echo ""
read -p "Enter ROOT Linux partition (example /dev/sda6): " ROOT_PART
read -p "Enter EFI partition (example /dev/sda1): " EFI_PART

echo ""
echo "⚠️ WARNING: This will format: $ROOT_PART"
read -p "Type YES to continue: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo "Formatting Linux partition..."
mkfs.ext4 $ROOT_PART

echo "Mounting system..."
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
mount $EFI_PART /mnt/boot/efi

echo "Installing base system..."
pacstrap /mnt base linux linux-firmware amd-ucode nano networkmanager grub efibootmgr os-prober sudo

genfstab -U /mnt >> /mnt/etc/fstab

echo "=============================="
echo "ENTER USER CONFIG"
echo "=============================="

USERNAME="ripe"
HOSTNAME="arch-hypr"

arch-chroot /mnt /bin/bash <<EOF

echo "Setting timezone..."
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc

echo "Setting locale..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

echo "Creating user..."
useradd -m -G wheel $USERNAME

echo "Enabling sudo..."
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo "Installing GRUB (dual boot)..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
os-prober
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing Hyprland desktop..."
pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
waybar kitty dunst pipewire pipewire-pulse wireplumber network-manager-applet git

echo "Installing gaming + GPU stack..."
pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils \
steam wine winetricks lutris vulkan-icd-loader lib32-vulkan-icd-loader

echo "Enabling services..."
systemctl enable NetworkManager

echo "DONE INSIDE CHROOT"
EOF

echo "=============================="
echo "SETTING PASSWORDS (FIXED)"
echo "=============================="

arch-chroot /mnt passwd root
arch-chroot /mnt passwd ripe

echo "Unmounting..."
umount -R /mnt

echo "=============================="
echo "INSTALL COMPLETE"
echo "Reboot and select GRUB to choose Windows or Arch"
echo "=============================="
