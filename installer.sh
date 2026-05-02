#!/bin/bash
set -e

echo "=============================="
echo " ARCH HYPRLAND FULL RICE INSTALLER"
echo " (Blur + Animations + GTK Sync + NVIDIA Safe)"
echo "=============================="

lsblk

read -p "ROOT partition: " ROOT_PART
read -p "EFI partition: " EFI_PART

echo "⚠️ WARNING: This will format ROOT: $ROOT_PART"
read -p "Type YES to continue: " CONFIRM
[ "$CONFIRM" != "YES" ] && exit 1

mkfs.ext4 "$ROOT_PART"
mount "$ROOT_PART" /mnt

mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

pacstrap /mnt base linux linux-firmware nano sudo git networkmanager \
grub efibootmgr os-prober dbus \
xorg-xwayland xorg-xinit

genfstab -U /mnt >> /mnt/etc/fstab

USERNAME="ripe"
HOSTNAME="arch-rice"

arch-chroot /mnt /bin/bash <<EOF
set -e

echo "===== BASE SYSTEM ====="

ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname

useradd -m -G wheel,video,input $USERNAME
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# =========================
# CORE DESKTOP STACK
# =========================
pacman -S --noconfirm \
hyprland xdg-desktop-portal-hyprland \
waybar kitty dunst wofi \
pipewire pipewire-pulse wireplumber \
polkit polkit-gnome \
network-manager-applet \
mesa vulkan-tools \
ttf-fira-code ttf-jetbrains-mono-nerd \
nwg-look gtk3 gtk4 \
papirus-icon-theme \
nvidia nvidia-utils lib32-nvidia-utils

systemctl enable NetworkManager
systemctl enable dbus

# =========================
# NVIDIA WAYLAND FIX
# =========================
sed -i 's/MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P

echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia.conf

mkdir -p /etc/environment.d
cat > /etc/environment.d/90-nvidia.conf <<EOL
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
LIBVA_DRIVER_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
EOL

# =========================
# GRUB (DUAL BOOT SAFE)
# =========================
sed -i 's/GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || true
grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub || echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="nvidia_drm.modeset=1 /' /etc/default/grub || true

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
os-prober || true
grub-mkconfig -o /boot/grub/grub.cfg

# =========================
# GREETD LOGIN
# =========================
pacman -S --noconfirm greetd greetd-tuigreet seatd
systemctl enable greetd

mkdir -p /etc/greetd
cat > /etc/greetd/config.toml <<EOL
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd Hyprland"
user = "$USERNAME"
EOL

systemctl enable seatd

# =========================
# HYPRLAND RICE CONFIG
# =========================
mkdir -p /home/$USERNAME/.config/hypr
cat > /home/$USERNAME/.config/hypr/hyprland.conf <<EOL

# ======================
# BASIC LOOK + FEEL
# ======================
monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1
}

general {
    gaps_in = 6
    gaps_out = 12
    border_size = 2
    col.active_border = rgba(89b4faee)
    col.inactive_border = rgba(313244aa)
}

decoration {
    rounding = 12

    blur {
        enabled = true
        size = 8
        passes = 3
    }

    drop_shadow = true
    shadow_range = 20
}

animations {
    enabled = true

    bezier = easeOut, 0.25, 1, 0.5, 1

    animation = windows, 1, 7, easeOut
    animation = fade, 1, 10, easeOut
    animation = workspaces, 1, 6, easeOut
}

exec-once = waybar
exec-once = dunst
exec-once = nm-applet
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
EOL

chown -R $USERNAME:$USERNAME /home/$USERNAME

# =========================
# GTK + ICON SYNC
# =========================
mkdir -p /home/$USERNAME/.config/gtk-3.0
mkdir -p /home/$USERNAME/.config/gtk-4.0

cat > /home/$USERNAME/.config/gtk-3.0/settings.ini <<EOL
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 11
EOL

cp /home/$USERNAME/.config/gtk-3.0/settings.ini /home/$USERNAME/.config/gtk-4.0/settings.ini

# =========================
# WAYBAR BASIC THEME
# =========================
mkdir -p /home/$USERNAME/.config/waybar
cat > /home/$USERNAME/.config/waybar/config <<EOL
{
  "layer": "top",
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "battery"]
}
EOL

cat > /home/$USERNAME/.config/waybar/style.css <<EOL
* {
    font-family: JetBrains Mono;
    font-size: 13px;
}
window {
    background: rgba(0,0,0,0.4);
    border-radius: 10px;
}
EOL

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

echo "exec Hyprland" > /home/$USERNAME/.xinitrc
chown $USERNAME:$USERNAME /home/$USERNAME/.xinitrc

EOF

echo "Set passwords:"
arch-chroot /mnt passwd root
arch-chroot /mnt passwd $USERNAME

umount -R /mnt

echo "=============================="
echo " INSTALL COMPLETE"
echo ""
echo "You now have:"
echo "- Blur + animations"
echo "- GTK theme sync"
echo "- Waybar rice"
echo "- NVIDIA Wayland support"
echo "- Dual boot GRUB"
echo ""
echo "If needed:"
echo "dbus-run-session Hyprland"
echo "startx"
echo "=============================="
