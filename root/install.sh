# --- Customization ---

USERNAME="${1:-user}"
PASSWORD="${2:-1234}"
BASE_INSTALLED="${3:-false}"
#KERNEL_ARGS="quiet splash"
KERNEL_ARGS="loglevel=7"
KERNEL="linux-tachyon"

# --- Actual install script ---

# Print commands
set -x

# Require superuser permission
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Create file systems
if [ "$BASE_INSTALLED" != "true" ]; then
  printf "label: gpt\n,256M,U\n,,\n" | sfdisk --wipe always --wipe-partitions always /dev/nvme0n1
  mkfs.fat -F 32 -n "ESP" /dev/nvme0n1p1
  mkfs.f2fs -l "ROOT" /dev/nvme0n1p2
fi
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

# Create swap
if [ "$BASE_INSTALLED" != "true" ]; then
  fallocate -l 8G /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile
fi
swapon /mnt/swapfile

# Install base system
dinitctl start ntpd
if [ "$BASE_INSTALLED" != "true" ]; then
  basestrap /mnt base base-devel dinit elogind-dinit
  set +e
  basestrap /mnt linux linux-firmware linux-headers uutils-coreutils-git
  set -e
  cp -r "$(dirname "$(realpath "$0")")/"../* /mnt
  read -r cmdline < /mnt/etc/kernel/cmdline
  printf "%s %s\n" "$cmdline" "$KERNEL_ARGS" > /mnt/etc/kernel/cmdline
fi

# Enter chroot
artix-chroot /mnt bash << EOF

  # Print commands
  set -x
  
  # Fix authentication issues
  pacman-key --init
  pacman-key --populate artix
  pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  pacman-key --lsign-key 3056513887B78AEB
  pacman -U "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst"
  pacman -U "https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"
  pacman -Sy --noconfirm alhp-keyring alhp-mirrorlist
  curl -O https://download.sublimetext.com/sublimehq-pub.gpg
  sudo pacman-key --add sublimehq-pub.gpg
  sudo pacman-key --lsign-key 8A8F901A
  rm sublimehq-pub.gpg
  gpg --locate-keys torvalds@kernel.org gregkh@kernel.org sashal@kernel.org benh@debian.org

  # Install kernel
  if [ "$BASE_INSTALLED" != "true" ]; then
    pacman -S --noconfirm git efibootmgr f2fs-tools amd-ucode networkmanager-dinit dhcpcd-dinit msedit egummiboot bc cpio python clang llvm lld
  fi
  cd /var/tmp
  sudo -u nobody git clone "https://aur.archlinux.org/$KERNEL.git"
  cd "$KERNEL"
  sudo -u nobody _use_llvm_lto="true" __subarch="MZEN3" MAKEFLAGS="--jobs=$(nproc)" PKGEXT=".pkg.tar" makepkg -cr --noconfirm --skippgpcheck
  pacman -U --noconfirm "$KERNEL.pkg.tar"
  cd ..
  sudo -u nobody git clone "https://aur.archlinux.org/$KERNEL-headers.git"
  cd "$KERNEL-headers"
  sudo -u nobody _use_llvm_lto="true" __subarch="MZEN3" MAKEFLAGS="--jobs=$(nproc)" PKGEXT=".pkg.tar" makepkg -cr --noconfirm --skippgpcheck
  pacman -U --noconfirm "$KERNEL-headers.pkg.tar"

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
  if [ "$BASE_INSTALLED" != "true" ]; then
    echo "root:$PASSWORD" | chpasswd
    useradd -m $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
  fi

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
