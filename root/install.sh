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
artix-chroot /mnt
hwclock --systohc
locale-gen
echo "root:__ROOT_PASSWORD__" | chpasswd
useradd -m __YOUR_USERNAME__
echo "__YOUR_USERNAME__:__YOUR_PASSWORD__" | chpasswd
pacman -S amd-ucode networkmanager-dinit dhcpd msedit egummiboot wpa_supplicant
ln -s ../NetworkManager /etc/dinit.d/boot.d/
mkinitcpio -p linux-ck
exit
unmout -lR /mnt
reboot
