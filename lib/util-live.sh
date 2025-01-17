#!/hint/bash

export LC_MESSAGES=C
export LANG=C

# {{{ functions

kernel_cmdline(){
    for param in $(cat /proc/cmdline); do
        case "${param}" in
            $1=*) echo "${param##*=}"; return 0 ;;
            "$1") return 0 ;;
            *) continue ;;
        esac
    done
    [ -n "${2}" ] && echo "${2}"
    return 1
}

get_lang(){
    kernel_cmdline lang
}

get_keytable(){
    kernel_cmdline keytable
}

get_tz(){
    kernel_cmdline tz
}

is_valid_de(){
    if [[ ${DEFAULT_DESKTOP_EXECUTABLE} != "none" ]] && \
    [[ ${DEFAULT_DESKTOP_FILE} != "none" ]]; then
        return 0
    fi
    return 1
}

detect_desktop_env(){
    local key val map
    map="${DATADIR}"/artools/desktop.map
    DEFAULT_DESKTOP_FILE="none"
    DEFAULT_DESKTOP_EXECUTABLE="none"
    while read -r item; do
        key=${item%:*}
        val=${item#*:}
        if [[ -f "${DATADIR}"/xsessions/$key.desktop ]] && [[ -f ${BINDIR}/$val ]];then
            DEFAULT_DESKTOP_FILE="$key"
            DEFAULT_DESKTOP_EXECUTABLE="$val"
        fi
    done < "$map"
    echo "Detected ${DEFAULT_DESKTOP_EXECUTABLE} ${DEFAULT_DESKTOP_FILE}" >> "${LOGFILE}"
}

configure_accountsservice(){
    local path=/var/lib/AccountsService/users user="${1:-${LIVEUSER}}"
    if [ -d "${path}" ] ; then
        echo "[User]" > ${path}/"$user"
        echo "XSession=${DEFAULT_DESKTOP_FILE}" >> ${path}/"$user"
        if [[ -f "/var/lib/AccountsService/icons/$user.png" ]];then
            echo "Icon=/var/lib/AccountsService/icons/$user.png" >> ${path}/"$user"
        fi
    fi
    echo "Configured accountsservice" >> "${LOGFILE}"
}

 set_lightdm_greeter(){
    local name
    for g in "${DATADIR}"/xgreeters/*.desktop;do
        name=${g##*/}
        name=${name%%.*}
        case ${name} in
            lightdm-gtk-greeter) break ;;
            lightdm-*-greeter)
                sed -e "s/^.*greeter-session=.*/greeter-session=${name}/" \
                    -i /etc/lightdm/lightdm.conf
            ;;
        esac
    done
 }

configure_displaymanager(){
    # Try to detect desktop environment
    # Configure display manager

    if [[ -f "${BINDIR}"/lightdm ]];then
        groupadd -r autologin
        gpasswd -a "${LIVEUSER}" autologin &> /dev/null
        set_lightdm_greeter
        if is_valid_de; then
            sed -e "s/^.*user-session=.*/user-session=$DEFAULT_DESKTOP_FILE/" \
                -e 's/^.*minimum-vt=.*/minimum-vt=7/' \
                -i /etc/lightdm/lightdm.conf
        fi
        ${AUTOLOGIN} && sed -e "s/^.*autologin-user=.*/autologin-user=${LIVEUSER}/" \
                -e "s/^.*autologin-user-timeout=.*/autologin-user-timeout=0/" \
                -e "s/^.*pam-autologin-service=.*/pam-autologin-service=lightdm-autologin/" \
                -i /etc/lightdm/lightdm.conf
    elif [[ -f "${BINDIR}"/gdm ]];then
        configure_accountsservice "gdm"
        ${AUTOLOGIN} && sed -e "s/\[daemon\]/\[daemon\]\nAutomaticLogin=${LIVEUSER}\nAutomaticLoginEnable=True/" \
                -i /etc/gdm/custom.conf
    elif [[ -f "${BINDIR}"/sddm ]];then
        if is_valid_de; then
            sed -e "s|^Session=.*|Session=$DEFAULT_DESKTOP_FILE.desktop|" \
                -i /etc/sddm.conf
        fi
        ${AUTOLOGIN} && sed -e "s|^User=.*|User=${LIVEUSER}|" \
                -i /etc/sddm.conf
    elif [[ -f "${BINDIR}"/lxdm ]];then
        if is_valid_de; then
            sed -e "s|^.*session=.*|session=${BINDIR}/${DEFAULT_DESKTOP_EXECUTABLE}|" \
                -i /etc/lxdm/lxdm.conf
        fi
        ${AUTOLOGIN} && sed -e "s/^.*autologin=.*/autologin=${LIVEUSER}/" \
                -i /etc/lxdm/lxdm.conf
    fi
    echo "Configured displaymanager" >> "${LOGFILE}"
}

find_legacy_keymap(){
    local file="${DATADIR}/artools/kbd-model.map" kt="$1"
    while read -r line || [[ -n $line ]]; do
        if [[ -z $line ]] || [[ $line == \#* ]]; then
            continue
        fi

        local mapping=( "$line" ); # parses columns
        if [[ ${#mapping[@]} != 5 ]]; then
            continue
        fi

        if  [[ "$kt" != "${mapping[0]}" ]]; then
            continue
        fi

        if [[ "${mapping[3]}" == "-" ]]; then
            mapping[3]=""
        fi

        X11_LAYOUT=${mapping[1]}
        X11_MODEL=${mapping[2]}
        X11_VARIANT=${mapping[3]}
        X11_OPTIONS=${mapping[4]}
    done < $file
}

write_x11_config(){
    # find a x11 layout that matches the keymap
    # in isolinux if you select a keyboard layout and a language that doesnt match this layout,
    # it will provide the correct keymap, but not kblayout value
    local X11_LAYOUT=
    local X11_MODEL="pc105"
    local X11_VARIANT=""
    local X11_OPTIONS="terminate:ctrl_alt_bksp"
    local kt="$1"

    find_legacy_keymap "$kt"

    # layout not found, use KBLAYOUT
    if [[ -z "$X11_LAYOUT" ]]; then
        X11_LAYOUT="$kt"
    fi

    # create X11 keyboard layout config
    mkdir -p "/etc/X11/xorg.conf.d"

    local XORGKBLAYOUT="/etc/X11/xorg.conf.d/00-keyboard.conf"

    echo "Section \"InputClass\"" > "$XORGKBLAYOUT"
    {
    echo " Identifier \"system-keyboard\""
    echo " MatchIsKeyboard \"on\""
    echo " Option \"XkbLayout\" \"$X11_LAYOUT\""
    echo " Option \"XkbModel\" \"$X11_MODEL\""
    echo " Option \"XkbVariant\" \"$X11_VARIANT\""
    echo " Option \"XkbOptions\" \"$X11_OPTIONS\""
    echo "EndSection"
    } >> "$XORGKBLAYOUT"
}

configure_language(){
    # hack to be able to set the locale on bootup
    local lang keytable timezone
    lang=$(get_lang)
    keytable=$(get_keytable)
    timezone=$(get_tz)

    sed -e "s/#${lang}.UTF-8/${lang}.UTF-8/" -i /etc/locale.gen

    echo "KEYMAP=${keytable}" > /etc/vconsole.conf
    echo "LANG=${lang}.UTF-8" > /etc/locale.conf
    ln -sf "${DATADIR}"/zoneinfo/"${timezone}" /etc/localtime

    write_x11_config "${keytable}"

    loadkeys "${keytable}"

    locale-gen "${lang}"
    {
    echo "Configured language: ${lang}"
    echo "Configured keymap: ${keytable}"
    echo "Configured timezone: ${timezone}"
    echo "Finished localization"
    } >> "${LOGFILE}"
}

configure_swap(){
    local swapdev
    swapdev="$(fdisk -l 2>/dev/null | grep swap | cut -d' ' -f1)"
    if [ -e "${swapdev}" ]; then
        swapon "${swapdev}"
    fi
    echo "Activated swap and added to fstab" >> "${LOGFILE}"
}

configure_branding(){
    if [[ -f "${BINDIR}"/neofetch ]]; then
        neofetch >| /etc/issue
        echo "Configured branding" >> "${LOGFILE}"
    fi
}

configure_user(){
    echo "root:${PASSWORD}" | chroot / chpasswd
    cp /etc/skel/.{bash_profile,bashrc,bash_logout} /root/

    mkdir /home/${LIVEUSER}
    chown ${LIVEUSER}:${LIVEUSER} /home/${LIVEUSER}
    echo "${LIVEUSER}:${PASSWORD}" | chroot / chpasswd
    cp -r /etc/skel/.[^.]* /home/${LIVEUSER}
    chown -R ${LIVEUSER}:${LIVEUSER} /home/${LIVEUSER}
    echo "Configured live user ${LIVEUSER} with password ${PASSWORD}" >> "${LOGFILE}"
}

# }}}


load_live_config(){

    [[ -f $1 ]] || return 1

    local live_conf="$1"

    [[ -r "${live_conf}" ]] && source "${live_conf}"

    AUTOLOGIN=${AUTOLOGIN:-true}

    PASSWORD=${PASSWORD:-artix}

    return 0
}

load_live_config "@sysconfdir@/artools/live.conf" || load_live_config "@datadir@/artools/live.conf"

LIVEUSER=@live@
DATADIR=@datadir@
BINDIR=@bindir@
