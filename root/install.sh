# --- Customization ---

USERNAME="${1:-user}"
PASSWORD="${2:-1234}"
#KERNEL_ARGS="quiet splash"
KERNEL_ARGS="loglevel=7"
KERNEL="linux-tachyon"

# --- Actual install script ---

# Print commands
set -x

# Fix authentication issues
pacman-key --init
pacman-key --populate

# Require superuser permission
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Create file systems
printf "label: gpt\n,256M,U\n,,\n" | sfdisk --wipe always --wipe-partitions always /dev/nvme0n1
mkfs.fat -F 32 -n "ESP" /dev/nvme0n1p1
mkfs.f2fs -l "ROOT" /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

# Create swap
fallocate -l 8G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# Install base system
dinitctl start ntpd
basestrap /mnt base base-devel dinit elogind-dinit
set +e
basestrap /mnt linux linux-firmware linux-headers
set -e
cp -r "$(dirname "$(realpath "$0")")/"../* /mnt
read -r cmdline < /mnt/etc/kernel/cmdline
printf "%s %s\n" "$cmdline" "$KERNEL_ARGS" > /mnt/etc/kernel/cmdline

# Enter chroot
artix-chroot /mnt bash << EOF

  # Install kernel
  pacman -Sy --noconfirm git mold efibootmgr f2fs-tools amd-ucode networkmanager-dinit dhcpcd-dinit msedit egummiboot wpa_supplicant
  cd /tmp
  git clone "https://aur.archlinux.org/$KERNEL.git"
  cd "$KERNEL"
  sudo -u nobody _use_llvm_lto="true" __subarch="MZEN3" CFLAGS="-O2 -march=native -pipe" LDFLAGS="-fuse-ld=mold" MAKEFLAGS="--jobs=$(nproc)" PKGEXT=".pkg.tar" makepkg -cr --noconfirm
  pacman -U --noconfirm "$KERNEL.pkg.tar"

  # Set boot entry
  efibootmgr -b 0000 -B
  efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Clover" -l "\EFI\BOOT\BOOTX64.efi"
  efibootmgr -o 0000

  # Update configuration files
  ln -s ../NetworkManager /etc/dinit.d/boot.d/
  ln -s ../dhcpcd /etc/dinit.d/boot.d/
  hwclock --systohc
  locale-gen

  # Set passwords
  echo "root:$PASSWORD" | chpasswd
  useradd -m $USERNAME
  echo "$USERNAME:$PASSWORD" | chpasswd

  # Finish install and exit
  mkinitcpio -p linux-tachyon
  exit

EOF

# Unmount install
bash "$(dirname "$(realpath "$0")")/"unmount.sh

# Reboot artix
read -p "Do you want to reboot (y/n)? " answer
case ${answer:0:1} in
  y|Y )
    echo "Reboot confirmed"
    countdown=10
    while [ $countdown -gt 0 ]; do
      echo "Rebooting in $countdown seconds..."
      sleep 1
      ((countdown--))
    done
    echo "Rebooting now"
    reboot
  ;;
  * )
    echo "Reboot canceled"
  ;;
esac
