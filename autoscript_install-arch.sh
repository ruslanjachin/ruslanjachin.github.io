#!/bin/bash
loadkeys ru
setfont ter-v18n
net="$(iwctl device list | awk '{print $2}' | tail -n 2 | xargs)"
if [ -z "$net" ];
then
wifi="";
else
read -p "Обнаружен wifi модуль, если основное подключение к интернету планируется через wifi введите имя сети, если через провод нажмите Enter:
" wifi;
fi
if [ -z "$wifi" ];
then
net="$(ip -br link show | grep -v UNKNOWN | grep -v DOWN | awk '{print $1}' | xargs)";
else
read -p "Пароль wifi:
" passwifi;
iwctl --passphrase $passwifi station $net connect $wifi;
fi
time="$(curl https://ipapi.co/timezone)"
timedatectl set-timezone $time
timedatectl status
lsblk -d
echo "
"
read -p "Введите метку диска на который будет установлена ОС: " disk
echo "
"
read -p "Введите имя компьютера: " hostname
echo "
"
read -p "Введите имя пользователя: " username
echo "
"
read -p "Введите пароль для $username: " passuser
echo "
"
read -p "Введите пароль для root: " passroot
boot="$(efibootmgr | grep Boot)"
if [ -z "$boot" ];
then
fdisk /dev/$disk <<EOF
g
n
1
2048
+512m
y

n
2

+1m
y
t
2
4
n
3

+1g
n
4


w
EOF
mkfs.ext2 /dev/${disk}1 -L boot<<EOF
y
EOF
mkswap /dev/${disk}3 -L swap
mkfs.ext4 /dev/${disk}4 -L root<<EOF
y
EOF
mount /dev/${disk}4 /mnt
mount --mkdir /dev/${disk}1 /mnt/boot
swapon /dev/${disk}3;
else
fdisk /dev/$disk <<EOF
g
n
1
2048
+512m
t

1
n
2

+1g
n
3


w
EOF
mkfs.fat -F32 /dev/${disk}1 -n boot
mkswap /dev/${disk}2 -L swap
mkfs.ext4 /dev/${disk}3 -L root<<EOF
y
EOF
mount /dev/${disk}3 /mnt
mount --mkdir /dev/${disk}1 /mnt/boot
swapon /dev/${disk}2;
fi
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware nano dhcpcd
genfstab -p -U /mnt >> /mnt/etc/fstab
net="$(ip -br link show | grep -v UNKNOWN | grep -v DOWN | cut -b1-10)"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$time /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
arch-chroot /mnt sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
echo 'LANG="ru_RU.UTF-8"' > /mnt/etc/locale.conf
echo "KEYMAP=ru
FONT=ter-v18n
USECOLOR=yes" > /mnt/etc/vconsole.conf
arch-chroot /mnt locale-gen
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname" > /mnt/etc/hosts
arch-chroot /mnt passwd<<EOF
$passroot
$passroot
EOF
arch-chroot /mnt useradd -m -g users -G wheel -s /bin/bash $username
arch-chroot /mnt passwd $username<<EOF
$passuser
$passuser
EOF
echo "$username ALL=(ALL:ALL) NOPASSWD: ALL" >> /mnt/etc/sudoers
boot="$(efibootmgr | grep Boot)"
if [ -z "$boot" ];
then
arch-chroot /mnt pacman -S grub --noconfirm
arch-chroot /mnt grub-install /dev/$disk
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg;
else
arch-chroot /mnt pacman -Sy efibootmgr --noconfirm
arch-chroot /mnt bootctl install
echo 'default arch
timeout 2
editor 0' > /mnt/boot/loader/loader.conf
echo "title  Arch Linux Virtual
linux  /vmlinuz-linux-zen
initrd  /initramfs-linux-zen.img
options root=/dev/${disk}3 rw" > /mnt/boot/loader/entries/arch.conf;
fi
arch-chroot /mnt sed -i 's/#Color/Color/' /etc/pacman.conf
echo '[multilib]
Include = /etc/pacman.d/mirrorlist' >> /mnt/etc/pacman.conf
echo 'kernel.sysrq=1' > /mnt/etc/sysctl.d/99-sysctl.conf
arch-chroot /mnt pacman -Sy reflector --noconfirm
arch-chroot /mnt sed -i 's/# --country France,Germany/--country Finland,Germany,Russia/' /etc/xdg/reflector/reflector.conf
arch-chroot /mnt pacman -Sy reflector --noconfirm
arch-chroot /mnt pacman -Sy xorg i3-gaps xorg-xinit xorg-apps xterm dmenu xdm-archlinux i3status git firefox numlockx gparted kwalletmanager ark mc htop conky polkit network-manager-applet acpid giflib lib32-giflib gtk4 gtk3 lib32-gtk3 gtk2 lib32-gtk2 dolphin kdf filelight ifuse usbmuxd libplist libimobiledevice curlftpfs samba kimageformats ffmpegthumbnailer kdegraphics-thumbnailers qt5-imageformats kdesdk-thumbnailers ffmpegthumbs ntfs-3g dosfstools kde-cli-tools qt5ct lxappearance-gtk3 papirus-icon-theme picom redshift tint2 grc flameshot xscreensaver notification-daemon adwaita-qt5 gnome-themes-extra variety alsa-utils alsa-plugins lib32-alsa-plugins alsa-firmware alsa-card-profiles pulseaudio pulseaudio-alsa pulseaudio-bluetooth pavucontrol freetype2 noto-fonts-extra noto-fonts-cjk ttf-joypixels audacity kdenlive cheese kwrite sweeper pinta gimp transmission-qt vlc libreoffice-still-ru ktouch kalgebra avidemux-qt copyq telegram-desktop discord step kamera gwenview imagemagick xreader sane skanlite cups cups-pdf avahi bluez bluez-utils bluez-cups bluez-hid2hci bluez-libs bluez-plugins bluez-qt bluez-tools python-bluepy python-pybluez blueman go wireless_tools --noconfirm
arch-chroot /mnt/ sudo -u $username sh -c "cd /home/$username/; git clone https://aur.archlinux.org/yay.git; cd /home/$username/yay; BUILDDIR=/tmp/makepkg makepkg -i --noconfirm"
rm -Rf /mnt/home/$username/yay
arch-chroot /mnt/ sudo -u $username yay -S transset-df hardinfo r-linux debtap volctl libreoffice-extension-languagetool --noconfirm
arch-chroot /mnt pacman -Ss geoclue2
echo 'userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap
if [ -f $sysresources ]; then
xrdb -merge $sysresources
fi
if [ -f $sysmodmap ]; then
xmodmap $sysmodmap
fi
if [ -f "$userresources" ]; then
xrdb -merge "$userresources"
fi
if [ -f "$usermodmap" ]; then
xmodmap "$usermodmap"
fi
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
[ -x "$f" ] && . "$f"
done
unset f
fi
xhost +si:localuser:root
exec i3' > /mnt/home/$username/.xinitrc
echo 'Section "InputClass"
Identifier "system-keyboard"
MatchIsKeyboard "on"
Option "XkbLayout" "us,ru"
Option "XkbOptions" "grp:alt_shift_toggle,terminate:ctrl_alt_bksp"
EndSection' > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
mkdir -p /mnt/etc/sane.d
echo 'localhost
192.168.0.0/24' >> /mnt/etc/sane.d/net.conf
mkdir -p /mnt/home/$username/.config/conky
echo 'conky.config = { --Внешний вид.
alignment = "middle_right", --Располжение виджета.
border_inner_margin = 20, --Отступ от внутренних границ.
border_width = 1, --Толщина рамки.
cpu_avg_samples = 2, --Усреднение значений нагрузки.
default_color = "#2bf92b", --Цвет по умолчанию.
default_outline_color = "#2bf92b", --Цвет рамки по умолчанию.
double_buffer = true, --Включение двойной буферизации.
draw_shades = false, --Оттенки.
draw_borders = true, --Включение границ.
font = "Noto Sans Mono:size=8", --Шрифт и размер шрифта.
gap_x = 30, --Отступ от края.
own_window = true, --Собственное окно.
own_window_class = "Conky", --Класс окна.
own_window_type = "override", --Тип окна (возможные варианты: "normal", "desktop", "ock", "panel", "override" выбираем в зависимости от оконного менеджера и личных предпочтений).
own_window_hints = "undecorated, skip_taskbar", --Задаем эфекты отображения окна.
own_window_argb_visual = true, --Прозрачность окна.
own_window_argb_value = 180, --Уровень прозрачности.
use_xft = true, } --Использование шрифтов X сервера.
conky.text = [[ #Наполнение виджета.
#Блок "Время".
#Часы.
${font :size=22}$alignc${color #f92b2b}$alignc${time %H:%M}$font$color
#Дата.
${font :size=10}$alignc${color #b2b2b2}${time %d %b %Y} (${time %a})$font$color
#Блок "Система".
#Разделитель.
${color #f92b2b}SYS${hr 3}$color
#Ядро.
${color #b2b2b2}Ядро:$color$alignr$kernel
#Время в сети.
${color #b2b2b2}Время в сети:$color$alignr$uptime
#Блок "ЦП".
#Разделитель.
${color #f92b2b}CPU${hr 3}$color
#Нагрузка ЦП.
${color #b2b2b2}Нагрузка ЦП:$color$alignr$cpu %
#Частота ЦП.
${color #b2b2b2}Частота ЦП:$color$alignr$freq MHz
#Температура ЦП.
${color #b2b2b2}Температура ЦП:$color$alignr${execi 10 sensors | grep "id 0:" | cut -b15-22}
#Температура Ядра 1.
$alignr${execi 10 sensors | grep "Core 0:" | cut -b1-22 }
#Температура Ядра 2.
$alignr${execi 10 sensors | grep "Core 1:" | cut -b1-22 }
#Температура Ядра 3.
$alignr${execi 10 sensors | grep "Core 2:" | cut -b1-22 }
#Температура Ядра 4.
$alignr${execi 10 sensors | grep "Core 3:" | cut -b1-22 }
#Блок "ОЗУ".
#Разделитель.
${color #f92b2b}RAM${hr 3}$color
#Задействовано ОЗУ.
${color #b2b2b2}Задействовано:$color$alignr$mem / $memmax
#Свободно ОЗУ.
${color #b2b2b2}Свободно:$color$alignr$memeasyfree / $memmax
#Полоса загрузки ОЗУ.
$memperc%${membar 4}
#Блок "Подкачка".
#Разделитель.
${color #f92b2b}SWAP${hr 3}$color
#Задействовано Подкачки.
${color #b2b2b2}Задействовано:$color$alignr$swap / $swapmax
#Полоса загрузки Подкачки.
$swapperc%${swapbar 4}
#Блок "Сеть".
#Разделитель.
${color #f92b2b}NET${hr 3}$color
#Скорость приёма ('${net}' определенно командой "ls /sys/class/net" в терминале).
${color #b2b2b2}Скорость приёма:$color$alignr${upspeedf '${net}'}
#Скорость отдачи.
${color #b2b2b2}Скорость отдачи:$color$alignr${downspeedf '${net}'}
#IP адрес.
${color #b2b2b2}IP адрес:$color$alignr${curl eth0.me}
#Блок "Процессы".
#Разделитель.
${color #f92b2b}Процессы${hr 3}$color
#Таблица процессов.
${color #b2b2b2}Название$alignr PID | CPU% | MEM% $color
#Информация о процессе 1.
${top name 1} $alignr ${top pid 1}|${top cpu 1}|${top mem 1}
#Информация о процессе 2.
${top name 2} $alignr ${top pid 2}|${top cpu 2}|${top mem 2}
#Информация о процессе 3.
${top name 3} $alignr ${top pid 3}|${top cpu 3}|${top mem 3}
#Информация о процессе 4.
${top name 4} $alignr ${top pid 4}|${top cpu 4}|${top mem 4}
#Информация о процессе 5.
${top name 5} $alignr ${top pid 5}|${top cpu 5}|${top mem 5}
#Блок "Диск1".
#Разделитель.
${color #f92b2b}/home${hr 3}$color
#Занято.
${color #b2b2b2}Задействовано:$color$alignr${fs_used /home/} / ${fs_size /home/}
#Свободно.
${color #b2b2b2}Свободно:$color$alignr${fs_free /home/} / ${fs_size /home/}
]]' > /mnt/home/$username/.config/conky/conky.conf
echo '[[ -f ~/.profile ]] && . ~/.profile' > /mnt/home/$username/.bash_profile
echo '[[ $- != *i* ]] && return #Определяем интерактивность шелла.
[ -n "$XTERM_VERSION" ] && transset-df --id "$WINDOWID" >/dev/null #Автоматическая прозрачность xterm.
alias grep="grep --color=auto" #Раскрашиваем grep.
alias ip="ip --color=auto" #Раскрашиваем ip.
alias ping="grc --colour=auto ping" #Раскрашиваем ping.
alias gcc="grc --colour=auto gcc" #Раскрашиваем gcc.
alias diff="grc --colour=auto diff" #Раскрашиваем diff.
alias log="grc --colour=auto log" #Раскрашиваем log.
alias cvs="grc --colour=auto cvs" #Раскрашиваем cvs.
alias mount="grc --colour=auto mount" #Раскрашиваем mount.
alias ps="grc --colour=auto ps" #Раскрашиваем ps.
alias ls="grc --colour=auto ls" #Раскрашиваем ls.
alias df="grc --colour=auto df" #Раскрашиваем df.
PS1="\[\e[2;32m\][\A]\[\e[0m\]\[\e[3;31m\][\u@\h \W]\[\e[0m\]\[\e[5;36m\]\$: \[\e[0m\]" #Изменяем вид приглашения командной строки.
#\[\e[2;32m\] 2 - более темный цвет, 32 - зеленый цвет.
#[\A] Текущее время в 24-часовом формате.
#\[\e[0m\] Конец изменениям.
#\[\e[3;31m\] 3 - курсив, 31 - красный цвет.
#[\u@\h \W] ИмяПользователя@имя хоста Текущий относительный путь.
#\[\e[0m\] Конец изменениям.
#\[\e[5;35m\] 5 - моргание, 36 - голубой цвет.
#\$: Символ приглашения (# для root, $ для обычных пользователей).
#\[\e[0m\] Конец изменениям.
export HISTCONTROL="ignoreboth" #Удаляем повторяющиеся записи и записи начинающиеся с пробела (например команды в mc) в .bash_history.
export COLORTERM=truecolor #Включаем все 16 миллионов цветов в эмуляторе терминала.' > /mnt/home/$username/.bashrc
echo 'setleds -D +num #Включенный по умолчанию NumLock.
[[ -f ~/.bashrc ]] && . ~/.bashrc #Указание на bashrc.
export QT_QPA_PLATFORMTHEME="qt5ct" #Изменение внешнего вида приложений использующих qt.' > /mnt/home/$username/.profile
echo '[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=/usr/lib/notification-daemon-1.0/notification-daemon' > /mnt/usr/share/dbus-1/services/org.freedesktop.Notifications.service
echo '# Прозрачность неактивных окон (0,1–1,0).
inactive-opacity = 0.8;
#
# Затемнение неактивных окон (0,0–1,0).
inactive-dim = 0.5
#
# Включить вертикальную синхронизацию (если picom выдает ошибку по vsync, то отключаем заменой true на false).
vsync = true;
#
# Отключить прозрачность и затемнение загаловков окон.
mark-ovredir-focused = true;
#
wintypes:
{
# Отключить прозрачность выпадающего меню.
dropdown_menu = { opacity = false; }
#
# Отключить прозрачность всплывающего меню.
popup_menu = { opacity = false; }
};' > /mnt/home/$username/.config/picom.conf
echo '!Настройка внешнего вида xterm.
!
!Задает имя типа терминала, которое будет установлено в переменной среды TERM.
xterm*termName: xterm-256color
!
!Xterm будет использовать кодировку, указанную в локали пользователя.
xterm*locale: true
!
!Определяет количество строк, сохраняемых за пределами верхней части экрана, когда включена полоса прокрутки.
xterm*saveLines: 14096
!
!Укажите шаблон для масштабируемых шрифтов.
xterm*faceName: Noto Sans Mono
!
!Размер шрифтов.
xterm*faceSize: 10
!
!Указывает цвет фона.
xterm*background: #2b0f2b
!Определяет цвет, который будет использоваться для переднего плана.
xterm*foreground: #2bf92b
!
!Указывает, должна ли отображаться полоса прокрутки.
xterm*scrollBar: true
!
!Определяет ширину полосы прокрутки.
xterm*scrollbar.width: 10
!
!Указывает, должно ли нажатие клавиши автоматически перемещать полосу прокрутки в нижнюю часть области прокрутки.
xterm*scrollKey: true
!
!Указывает, должна ли полоса прокрутки отображаться справа.
xterm*rightScrollBar: true
!
!
!Настройка внешнего вида xscreensaver.
!
!Указывает шрифт.
xscreensaver-auth.?.Dialog.headingFont: Noto Sans Mono 12
xscreensaver-auth.?.Dialog.bodyFont: Noto Sans Mono 12
xscreensaver-auth.?.Dialog.labelFont: Noto Sans Mono 12
xscreensaver-auth.?.Dialog.unameFont: Noto Sans Mono 12
xscreensaver-auth.?.Dialog.buttonFont: Noto Sans Mono 12
xscreensaver-auth.?.Dialog.dateFont: Noto Sans Mono 12
xscreensaver-auth.?.passwd.passwdFont: Noto Sans Mono 12
!
!Указывает цвета.
xscreensaver-auth.?.Dialog.foreground: #b2f9b2
xscreensaver-auth.?.Dialog.background: #b20fb2
xscreensaver-auth.?.Dialog.Button.foreground: #b20fb2
xscreensaver-auth.?.Dialog.Button.background: #b2f9b2
xscreensaver-auth.?.Dialog.text.foreground: #b20fb2
xscreensaver-auth.?.Dialog.text.background: #b2f9b2
xscreensaver-auth.?.passwd.thermometer.foreground: #f92b2b
xscreensaver-auth.?.passwd.thermometer.background: #b2f9b2' > /mnt/home/$username/.Xresources
mkdir -p /mnt/home/$username/.config/i3
echo '########### Основные настройки ###########
#
# Назначаем клавишу MOD, Mod4 - это клавиша WIN.
set $mod Mod4
#
# Закрыть окно в фокусе.
bindsym $mod+Shift+q kill
# Средняя кнопка мыши над заголовком закрывает окно.
bindsym --release button2 kill
#
# Изменить фокус на другое окно (semicolon - это клавиша ;:жЖ).
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right
# Альтернативные настройки смены фокуса на другое окно.
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right
#
# Переместить окно.
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right
# Альтернативные настройки перемешения окна.
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right
# Боковые кнопки мыши перемещают окно.
bindsym button9 move left
bindsym button8 move right
#
# Следующее открытое окно разделит экран по горизонтали (такое деление установленно по умолчанию). Легко запомнить по первой букве Horizontal.
bindsym $mod+h split h
#
# Следующее открытое окно разделит экран по вертикали. Легко запомнить по первой букве Vertical.
bindsym $mod+v split v
#
# Развернуть окно во весь экран. Легко запомнить по первой букве Fullscreen.
bindsym $mod+f fullscreen toggle
#
# Делаем из окон вкладки.
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
#
# Делаем окно плавающим.
bindsym $mod+Shift+space floating toggle
# Правая кнопка мыши делает окно плавающим.
bindsym button3 floating toggle
bindsym $mod+button3 floating toggle
#
# Изменить фокус между мозаичными / плавающими окнами.
bindsym $mod+space focus mode_toggle
#
# Определяем имена для рабочих областей по умолчанию.
set $ws1 "1"
set $ws2 "2: 🌍"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"
#
# Переключение между рабочими столами.
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10
#
# Переместить сфокусированное окно на заданный рабочий стол.
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10
#
# Перечитать файл конфигурации.
bindsym $mod+Shift+c reload
#
# Перезапустить i3 (сохраняет макет/сессию, может использоваться для обновления i3).
bindsym $mod+Shift+r restart
#
# Выход из i3 (выходит из сеанса X).
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m "Вы действительно хотите выйти из i3? Это завершит вашу сессию X." -B "Да, выйти из i3" "i3-msg exit""
#
# Войти в режим изменения размеров окон.
bindsym $mod+r mode "resize"
# Изменить размер окна (можно использовать мышь).
mode "resize" {
#
        # Настройки смены размеров окон.
        bindsym j resize shrink width 10 px or 10 ppt
        bindsym k resize grow height 10 px or 10 ppt
        bindsym l resize shrink height 10 px or 10 ppt
        bindsym semicolon resize grow width 10 px or 10 ppt
        #
        # Альтернативные настройки смены размеров окон (мне показались более удобными).
        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize grow height 10 px or 10 ppt
        bindsym Up resize shrink height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt
        #
        # Выйти из режима изменения размеров окон.
        bindsym Return mode "default"
        bindsym Escape mode "default"
        bindsym $mod+r mode "default"
}
#
# Некоторые видеодрайверы X11 обеспечивают поддержку только Xinerama вместо RandR.
# В такой ситуации нужно сказать i3, чтобы он явно использовал подчиненный Xinerama API.
force_xinerama yes
#
########### Внешний вид ###########
#
# Шрифт для заголовков окон. Также будет использоваться ibar, если не выбран другой шрифт.
font pango:Noto Sans Mono 8
#
# Просветы между окнами.
gaps inner 10
#
# Толщина границы окна.
default_border normal 3
#
# Толщина границы плавающего окна.
default_floating_border normal 3
#
# Устанавливаем цвет рамки активного окна #Граница #ФонТекста #Текст #Индикатор #ДочерняяГраница.
client.focused #2b2bf9 #2b2bf9 #2bf92b #2b2bf9 #2b2bf9
#
# Устанавливаем цвет рамки неактивного окна #Граница #ФонТекста #Текст #Индикатор #ДочерняяГраница.
client.unfocused #2b2b0f #2b2b0f #b2b2b2 #2b2b0f #2b2b0f
#
# Печатать все заголовки окон жирным, красным шрифтом.
# for_window [all] title_format "<span foreground="#d64c2f"><b>Заголовок | %title</b></span>"
#
# Включить значки окон для всех окон с дополнительным горизонтальным отступом.
for_window [all] title_window_icon padding 3px
#
# Внешний вид XTerm
# Включить плавающий режим для всех окон XTerm.
for_window [class="XTerm"] floating enable
# Сделать границу в 1 пиксель для всех окон XTerm.
for_window [class="XTerm"] border normal 1
# Липкие плавающие окна, окно XTerm прилипло к стеклу.
for_window [class="XTerm"] sticky enable
# Задаем размеры окна XTerm.
for_window [class="XTerm"] resize set 1000 500
#
########### Автозапуск программ ###########
#
# Запуск графического интерфейса системного трея NetworkManager (--no-startup-id убирает курсор загрузки).
exec --no-startup-id nm-applet
#
# Запуск геолокации (--no-startup-id убирает курсор загрузки).
exec --no-startup-id /usr/lib/geoclue-2.0/demos/agent
#
# Автозапуск volctl.
exec --no-startup-id volctl
#
# Автозапуск flameshot.
exec --no-startup-id flameshot
#
# Автозапуск copyq.
exec --no-startup-id copyq
#
# Автозапуск tint2.
exec --no-startup-id tint2
#
# Автозапуск picom.
exec --no-startup-id picom -b
#
# Автозапуск conky.
exec --no-startup-id conky
#
# Автозапуск numlockx.
exec --no-startup-id numlockx
#
# Автозапуск transmission.
exec --no-startup-id transmission-qt -m
#
# Автозапуск blueman-applet.
exec --no-startup-id blueman-applet
#
# Приветствие в течении 10 сек.
exec --no-startup-id notify-send -t 10000 "✊Доброго времени суток✊"
#
# Автозапуск xscreensaver.
exec --no-startup-id xscreensaver --no-splash
#
# Автозапуск dolphin.
exec --no-startup-id dolphin --daemon
#
# Автозапуск telegram.
exec --no-startup-id telegram-desktop -startintray -- %u
#
# Автозапуск variety.
exec --no-startup-id variety
#
# Автоматическая разблокировка KWallet.
exec --no-startup-id /usr/lib/pam_kwallet_init
#
########### Горячие клавиши запуска программ ###########
#
# Используйте mod+enter, чтобы запустить терминал ("i3-sensible-terminal" можно заменить "xterm", "terminator" или любым другим на выбор).
bindsym $mod+Return exec i3-sensible-terminal
#
# Запуск dmenu (программа запуска) с параметрами шрифта, приглашения, цвета фона.
bindsym $mod+d exec --no-startup-id dmenu_run -fn "Noto Sans Mono-15" -p "Поиск программы:" -nb "#2b0f2b" -sf "#2b2b0f" -nf "#2bf02b" -sb "#f92b2b"
#
# Используйте mod+f1, чтобы запустить firefox.
bindsym $mod+F1 exec --no-startup-id firefox
#
# Сделать текущее окно черновиком/блокнотом.
bindsym $mod+Shift+minus move scratchpad
#
# Показать первое окно черновика/блокнота.
bindsym $mod+minus scratchpad show
#
########### Распределение окон по рабочим столам ###########
#
# Firefox будет запускаться на 2 рабочем столе.
assign [class="firefox"] "2: 🌍"
#
########### Настройка панели задач ###########
#
bar {
        # Назначить панели задач.
        status_command i3status
        #
        # Разделитель.
        separator_symbol "☭"
        #
        # Назначить шрифт.
        font pango:Noto Sans Mono 12
        #
        # Назначить цвета.
        colors {
            # Цвет фона i3status.
            background #2b0f2b
            #
            # Цвет текста в i3status.
            statusline #2bf92b
            #
            # Цвет разделителя в i3status.
            separator #f92b2b
            }
         # Сделайте снимок экрана, щелкнув правой кнопкой мыши на панели (--no-startup-id убирает курсор загрузки).
         bindsym --release button3 exec --no-startup-id import ~/latest-screenshot.png
}' > /mnt/home/$username/.config/i3/config
echo 'general { #Основные настройки.
    colors = true #Включение/выключение поддержки цветов.
    color_good = "#2bf92b" #Цвет OK.
    color_bad = "#f92b2b" #Цвет ошибки.
    interval = 1 #Интервал обновления строки статуса.
    output_format = "i3bar" } #Формат вывода.
order += "ethernet _first_" #1 модуль - rj45.
order += "run_watch openvpn" #2 модуль - openvpn.
order += "run_watch openconnect" #3 модуль - openconnect.
order += "wireless _first_" #4 модуль - Wi-Fi.
order += "battery all" #5 модуль - батарея.
order += "disk /" #6 модуль - root директория.
order += "memory" #7 модуль - ram.
order += "cpu_usage" #8 модуль - использование ЦП.
order += "cpu_temperature 0" #9 модуль - температура ЦП.
order += "tztime local" #10 модуль - время.
order += "volume master" #11 модуль - звук.
ethernet _first_ { #Индикатор rj45.
        format_up = "🖧: %ip (%speed)" #Формат вывода.
        format_down = "" } #При неактивном процессе блок будет отсутствовать.
run_watch openvpn { #Индикатор openvpn.
    pidfile = "/var/run/openvpn.pid" #Путь данных.
    format = "🖧 openvpn" #Формат вывода.
    format_down="" } #При неактивном процессе блок будет отсутствовать.
run_watch openconnect { #Индикатор openconnect.
    pidfile = "/var/run/openconnect.pid" #Путь данных.
    format = "🖧 vpn" #Формат вывода.
    format_down="" } #При неактивном процессе блок будет отсутствовать.
wireless _first_ { #Индикатор WI-FI.
    format_up = "📶%quality %frequency %essid %ip" #Формат вывода.
    format_down = "" } #При неактивном процессе блок будет отсутствовать.
battery all { #Индикатор батареи
    format = "%status %percentage" #Формат вывода.
    last_full_capacity = true #Процент заряда.
    format_down = "" #При неактивном процессе блок будет отсутствовать.
    status_chr = "🔌" #Подзарядка.
    status_bat = "🔋" #Режим работы от батареи.
    path = "/sys/class/power_supply/BAT%d/uevent" #Путь данных.
    low_threshold = 10 } #Нижний порог заряда.
disk "/" { #Root директория.
    format = "♚ %avail / %total" } #Формат вывода.
memory { #Индикатор ram
    format = "🗂 %used" #Формат вывода.
    threshold_degraded = "1G" #Желтый порог.
    threshold_critical = "200M" #Красный порог.
    format_degraded = "MEMORY 🗂 %available" } #Формат вывода желтого/красного порога.
cpu_usage { #Использование ЦП.
    format = "🖳 %usage" } #Формат вывода.
cpu_temperature 0 { #Температура ЦП.
    format = "🌡 %degrees°C" #Формат вывода.
    max_threshold = "80" #Красный порог.
    format_above_threshold = "🌡 %degrees°C" #Формат вывода красного порога.
    path = "/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input"} #Путь данных.
tztime local { #Вывод даты и времени.
    format = "📅 %a %d-%m-%Y(%W) 🕗 %H:%M:%S" } #Формат вывода.
volume master { #Вывод звука.
    format = "🔈 %volume" #Формат вывода.
    format_muted = "🔇 %volume" } #Формат вывода без звука.' > /mnt/home/$username/.i3status.conf
echo '[redshift]
allowed=true
system=false
users=' >> /mnt/etc/geoclue/geoclue.conf
echo 'polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});' > /mnt/etc/polkit-1/rules.d/49-nopasswd_global.rules
fstrim -v -a
if [ -z "$wifi" ];
then
arch-chroot /mnt ip link set $net up
else
arch-chroot /mnt pacman -Sy iwd  --noconfirm
arch-chroot /mnt systemctl enable iwd
arch-chroot /mnt ip link set $net up
mkdir -p /mnt/var/lib/iwd
cp /var/lib/iwd/$wifi.psk /mnt/var/lib/iwd/$wifi.psk
fi
arch-chroot /mnt systemctl enable avahi-daemon saned.socket cups.socket bluetooth acpid cups-browsed fstrim.timer reflector.timer xdm-archlinux dhcpcd
arch-chroot /mnt systemctl --user --global enable redshift-gtk
arch-chroot /mnt chmod u+x /home/$username/.xinitrc
arch-chroot /mnt chown -R $username:users /home/$username/
umount -R /mnt
reboot
