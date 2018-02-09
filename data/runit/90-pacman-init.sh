msg "Mounting temporary gnupg directory"
mount -t tmpfs -o size=10M,mode=0755 tmpfs /etc/pacman.d/gnupg

msg "Initializing pacman"
pacman-key --init
pacman-key --populate archlinux-artix
