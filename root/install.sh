su root
printf "label: gpt\n,256M,U\n,,\n" | sfdisk --wipe always --wipe-partitions always /dev/nvme0n1
mkfs.fat -F 32 -n "ESP" /dev/nvme0n1p1
mkfs.f2fs -l "ROOT" /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
fallocate -l 8G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
dinitctl start ntpd
basestrap /mnt base base-devel dinit elogind-dinit
basestrap /mnt linux-ck linux-firmware linux-headers mkinitcpio
cp -r "$(dirname "$(realpath "$0")")/"* /mnt
artix-chroot /mnt
pacman -Sy efibootmgr f2fs-tools amd-ucode networkmanager-dinit dhcpcd-dinit msedit egummiboot wpa_supplicant
efibootmgr -b 0000 -B
efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Clover" -l "\EFI\BOOT\BOOTX64.efi"
efibootmgr -o 0000
ln -s ../NetworkManager /etc/dinit.d/boot.d/
ln -s ../dhcpcd /etc/dinit.d/boot.d/
hwclock --systohc
locale-gen
echo "root:__ROOT_PASSWORD__" | chpasswd
useradd -m __YOUR_USERNAME__
echo "__YOUR_USERNAME__:__YOUR_PASSWORD__" | chpasswd
mkinitcpio -p linux-ck
exit
unmout -lR /mnt
reboot
