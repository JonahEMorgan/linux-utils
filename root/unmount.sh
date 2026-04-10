# Require superuser permission
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# Unmount install
swapoff /mnt/swapfile
umount -R /mnt
