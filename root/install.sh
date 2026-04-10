dinitctl start ntpd
basestrap /mnt base base-devel dinit elogind-dinit
basestrap /mnt linux-ck linux-firmware linux-headers mkinitcpio
artix-chroot /mnt
hwclock --systohc
locale-gen
echo "root:morgan" | chpasswd
useradd -m jonah
echo "jonah:morgan" | chpasswd
pacman -S intel-ucode networkmanager-dinit dhcpd msedit egummiboot wpa_supplicant
ln -s ../NetworkManager /etc/dinit.d/boot.d/
exit
unmout -lR /mnt
reboot
