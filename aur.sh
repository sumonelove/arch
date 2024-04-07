cd /home/sum
sudo git clone https://aur.archlinux.org/yay.git
sudo chown -R  sum:sum yay
cd yay
makepkg -sri --needed --noconfirm
cd /dotf