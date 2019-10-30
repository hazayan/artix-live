#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

export LC_MESSAGES=C
export LANG=C

kernel_cmdline(){
    for param in $(cat /proc/cmdline); do
        case "${param}" in
            $1=*) echo "${param##*=}"; return 0 ;;
            $1) return 0 ;;
            *) continue ;;
        esac
    done
    [ -n "${2}" ] && echo "${2}"
    return 1
}

get_lang(){
    echo $(kernel_cmdline lang)
}

get_keytable(){
    echo $(kernel_cmdline keytable)
}

get_tz(){
    echo $(kernel_cmdline tz)
}

load_live_config(){

    [[ -f $1 ]] || return 1

    local live_conf="$1"

    [[ -r ${live_conf} ]] && source ${live_conf}

    AUTOLOGIN=${AUTOLOGIN:-true}

    USER_NAME=${USER_NAME:-"artix"}

    PASSWORD=${PASSWORD:-"artix"}

    ADDGROUPS=${ADDGROUPS:-"video,power,cdrom,network,lp,scanner,wheel,users,log"}

    return 0
}

is_valid_de(){
    if [[ ${DEFAULT_DESKTOP_EXECUTABLE} != "none" ]] && \
    [[ ${DEFAULT_DESKTOP_FILE} != "none" ]]; then
        return 0
    else
        return 1
    fi
}

load_desktop_map(){
    local _space="s| ||g" _clean=':a;N;$!ba;s/\n/ /g' _com_rm="s|#.*||g" \
        file=/usr/share/artools/desktop.map
    local desktop_map=$(sed "$_com_rm" "$file" | sed "$_space" | sed "$_clean")
    echo ${desktop_map}
}

detect_desktop_env(){
    local xs=/usr/share/xsessions ex=/usr/bin key val map=( $(load_desktop_map) )
    DEFAULT_DESKTOP_FILE="none"
    DEFAULT_DESKTOP_EXECUTABLE="none"
    for item in "${map[@]}";do
        key=${item%:*}
        val=${item#*:}
        if [[ -f $xs/$key.desktop ]] && [[ -f $ex/$val ]];then
            DEFAULT_DESKTOP_FILE="$key"
            DEFAULT_DESKTOP_EXECUTABLE="$val"
        fi
    done
}

configure_accountsservice(){
    local path=/var/lib/AccountsService/users
    if [ -d "${path}" ] ; then
        echo "[User]" > ${path}/$1
        echo "XSession=${DEFAULT_DESKTOP_FILE}" >> ${path}/$1
        if [[ -f "/var/lib/AccountsService/icons/$1.png" ]];then
            echo "Icon=/var/lib/AccountsService/icons/$1.png" >> ${path}/$1
        fi
    fi
}

 set_lightdm_greeter(){
    local greeters=$(ls /usr/share/xgreeters/*greeter.desktop) name
    for g in ${greeters[@]};do
        name=${g##*/}
        name=${name%%.*}
        case ${name} in
            lightdm-gtk-greeter) break ;;
            lightdm-*-greeter)
                sed -i -e "s/^.*greeter-session=.*/greeter-session=${name}/" /etc/lightdm/lightdm.conf
            ;;
        esac
    done
 }

 set_lightdm_vt(){
	sed -i -e 's/^.*minimum-vt=.*/minimum-vt=7/' /etc/lightdm/lightdm.conf
 }

configure_displaymanager(){
    # Try to detect desktop environment
    # Configure display manager
    if [[ -f /usr/bin/lightdm ]];then
        groupadd -r autologin
        set_lightdm_vt
        set_lightdm_greeter
        if $(is_valid_de); then
                sed -i -e "s/^.*user-session=.*/user-session=$DEFAULT_DESKTOP_FILE/" /etc/lightdm/lightdm.conf
        fi
        if ${AUTOLOGIN};then
            gpasswd -a ${USER_NAME} autologin &> /dev/null
            sed -i -e "s/^.*autologin-user=.*/autologin-user=${USER_NAME}/" /etc/lightdm/lightdm.conf
            sed -i -e "s/^.*autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
            sed -i -e "s/^.*pam-autologin-service=.*/pam-autologin-service=lightdm-autologin/" /etc/lightdm/lightdm.conf
        fi
    elif [[ -f /usr/bin/gdm ]];then
        configure_accountsservice "gdm"
        if ${AUTOLOGIN};then
            sed -i -e "s/\[daemon\]/\[daemon\]\nAutomaticLogin=${USER_NAME}\nAutomaticLoginEnable=True/" /etc/gdm/custom.conf
        fi
    elif [[ -f /usr/bin/sddm ]];then
        if $(is_valid_de); then
            sed -i -e "s|^Session=.*|Session=$DEFAULT_DESKTOP_FILE.desktop|" /etc/sddm.conf
        fi
        if ${AUTOLOGIN};then
            sed -i -e "s|^User=.*|User=${USER_NAME}|" /etc/sddm.conf
        fi
    elif [[ -f /usr/bin/lxdm ]];then
        if $(is_valid_de); then
            sed -i -e "s|^.*session=.*|session=/usr/bin/${DEFAULT_DESKTOP_EXECUTABLE}|" /etc/lxdm/lxdm.conf
        fi
        if ${AUTOLOGIN};then
            sed -i -e "s/^.*autologin=.*/autologin=${USER_NAME}/" /etc/lxdm/lxdm.conf
        fi
    fi
}

gen_pw(){
    echo $(perl -e 'print crypt($ARGV[0], "password")' ${PASSWORD})
}

find_legacy_keymap(){
    local file="/usr/share/artools/kbd-model.map" kt="$1"
    while read -r line || [[ -n $line ]]; do
        if [[ -z $line ]] || [[ $line == \#* ]]; then
            continue
        fi

        local mapping=( $line ); # parses columns
        if [[ ${#mapping[@]} != 5 ]]; then
            continue
        fi

        if  [[ "$kt" != "${mapping[0]}" ]]; then
            continue
        fi

        if [[ "${mapping[3]}" = "-" ]]; then
            mapping[3]=""
        fi

        X11_LAYOUT=${mapping[1]}
        X11_MODEL=${mapping[2]}
        X11_VARIANT=${mapping[3]}
        x11_OPTIONS=${mapping[4]}
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

    echo "" >> "$XORGKBLAYOUT"
    echo "Section \"InputClass\"" > "$XORGKBLAYOUT"
    echo " Identifier \"system-keyboard\"" >> "$XORGKBLAYOUT"
    echo " MatchIsKeyboard \"on\"" >> "$XORGKBLAYOUT"
    echo " Option \"XkbLayout\" \"$X11_LAYOUT\"" >> "$XORGKBLAYOUT"
    echo " Option \"XkbModel\" \"$X11_MODEL\"" >> "$XORGKBLAYOUT"
    echo " Option \"XkbVariant\" \"$X11_VARIANT\"" >> "$XORGKBLAYOUT"
    echo " Option \"XkbOptions\" \"$X11_OPTIONS\"" >> "$XORGKBLAYOUT"
    echo "EndSection" >> "$XORGKBLAYOUT"
}

configure_language(){
    # hack to be able to set the locale on bootup
    local lang=$(get_lang)
    local keytable=$(get_keytable)
    local timezone=$(get_tz)

    sed -e "s/#${lang}.UTF-8/${lang}.UTF-8/" -i /etc/locale.gen

    if [[ -d /run/openrc ]]; then
        sed -i "s/keymap=.*/keymap=\"${keytable}\"/" /etc/conf.d/keymaps
    fi
    echo "KEYMAP=${keytable}" > /etc/vconsole.conf
    echo "LANG=${lang}.UTF-8" > /etc/locale.conf
    ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime

    write_x11_config "${keytable}"

    loadkeys "${keytable}"

    locale-gen ${lang}
    echo "Configured language: ${lang}" >> "${LOGFILE}"
    echo "Configured keymap: ${keytable}" >> "${LOGFILE}"
    echo "Configured timezone: ${timezone}" >> "${LOGFILE}"
}

configure_swap(){
    local swapdev="$(fdisk -l 2>/dev/null | grep swap | cut -d' ' -f1)"
    if [ -e "${swapdev}" ]; then
        swapon ${swapdev}
    fi
}

configure_user(){
    local user="$1"
    if [[ "$user" == 'root' ]];then
        echo "root:${PASSWORD}" | chroot / chpasswd
        cp /etc/skel/.{bash_profile,bashrc,bash_logout} /root/
    else
        local args=(-m -G ${ADDGROUPS} -s /bin/bash $user)
        # set up user and password
        [[ -n ${PASSWORD} ]] && args+=(-p $(gen_pw))
        useradd "${args[@]}"
    fi
}
