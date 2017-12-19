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

get_cal_mode(){
    echo $(kernel_cmdline netinstall)
}

get_timer_ms(){
    echo $(date +%s%3N)
}

# $1: start timer
elapsed_time_ms(){
    echo $(echo $1 $(get_timer_ms) | awk '{ printf "%0.3f",($2-$1)/1000 }')
}

load_live_config(){

    [[ -f $1 ]] || return 1

    live_conf="$1"

    [[ -r ${live_conf} ]] && source ${live_conf}

    [[ -z ${autologin} ]] && autologin=true

    [[ -z ${username} ]] && username="artix"

    [[ -z ${password} ]] && password="artix"

    [[ -z ${addgroups} ]] && addgroups="video,power,storage,optical,network,lp,scanner,wheel,users,audio"

    echo "Loaded ${live_conf}: $(elapsed_time_ms ${livetimer})ms" >> "${LOGFILE}"

    return 0
}

is_valid_de(){
    if [[ ${default_desktop_executable} != "none" ]] && \
    [[ ${default_desktop_file} != "none" ]]; then
        return 0
    else
        return 1
    fi
}

load_desktop_map(){
    local _space="s| ||g" _clean=':a;N;$!ba;s/\n/ /g' _com_rm="s|#.*||g" \
        file=${DATADIR}/desktop.map
    local desktop_map=$(sed "$_com_rm" "$file" | sed "$_space" | sed "$_clean")
    echo ${desktop_map}
}

detect_desktop_env(){
    local xs=/usr/share/xsessions ex=/usr/bin key val map=( $(load_desktop_map) )
    default_desktop_file="none"
    default_desktop_executable="none"
    for item in "${map[@]}";do
        key=${item%:*}
        val=${item#*:}
        if [[ -f $xs/$key.desktop ]] && [[ -f $ex/$val ]];then
            default_desktop_file="$key"
            default_desktop_executable="$val"
        fi
    done
}

configure_accountsservice(){
    local path=/var/lib/AccountsService/users
    if [ -d "${path}" ] ; then
        echo "[User]" > ${path}/$1
        echo "XSession=${default_desktop_file}" >> ${path}/$1
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
                sed -i -e "s/^.*user-session=.*/user-session=$default_desktop_file/" /etc/lightdm/lightdm.conf
        fi
        if ${autologin};then
            gpasswd -a ${username} autologin &> /dev/null
            sed -i -e "s/^.*autologin-user=.*/autologin-user=${username}/" /etc/lightdm/lightdm.conf
            sed -i -e "s/^.*autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
            sed -i -e "s/^.*pam-autologin-service=.*/pam-autologin-service=lightdm-autologin/" /etc/lightdm/lightdm.conf
        fi
    elif [[ -f /usr/bin/gdm ]];then
        configure_accountsservice "gdm"
        if ${autologin};then
            sed -i -e "s/\[daemon\]/\[daemon\]\nAutomaticLogin=${username}\nAutomaticLoginEnable=True/" /etc/gdm/custom.conf
        fi
    elif [[ -f /usr/bin/sddm ]];then
        if $(is_valid_de); then
            sed -i -e "s|^Session=.*|Session=$default_desktop_file.desktop|" /etc/sddm.conf
        fi
        if ${autologin};then
            sed -i -e "s|^User=.*|User=${username}|" /etc/sddm.conf
        fi
    elif [[ -f /usr/bin/lxdm ]];then
        if $(is_valid_de); then
            sed -i -e "s|^.*session=.*|session=/usr/bin/$default_desktop_executable|" /etc/lxdm/lxdm.conf
        fi
        if ${autologin};then
            sed -i -e "s/^.*autologin=.*/autologin=${username}/" /etc/lxdm/lxdm.conf
        fi
    fi
}

gen_pw(){
    echo $(perl -e 'print crypt($ARGV[0], "password")' ${password})
}

configure_user(){
    # set up user and password
    if [[ -n ${password} ]];then
            useradd -m -G ${addgroups} -p $(gen_pw) -s /bin/bash ${username}
    else
            useradd -m -G ${addgroups} -s /bin/bash ${username}
    fi
}

find_legacy_keymap(){
    local file="${DATADIR}/kbd-model.map"
    while read -r line || [[ -n $line ]]; do
        if [[ -z $line ]] || [[ $line == \#* ]]; then
            continue
        fi

        mapping=( $line ); # parses columns
        if [[ ${#mapping[@]} != 5 ]]; then
            continue
        fi

        if  [[ "${keytable}" != "${mapping[0]}" ]]; then
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

    find_legacy_keymap

    # layout not found, use KBLAYOUT
    if [[ -z "$X11_LAYOUT" ]]; then
        X11_LAYOUT="${keytable}"
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
    keytable=$(get_keytable)
    local timezone=$(get_tz)
    # Fallback
#     [[ -z "${lang}" ]] && lang="en_US"
#     [[ -z "${keytable}" ]] && keytable="us"
#     [[ -z "${timezone}" ]] && timezone="Etc/UTC"

    sed -e "s/#${lang}.UTF-8/${lang}.UTF-8/" -i /etc/locale.gen

    # 	echo "LANG=${lang}.UTF-8" >> /etc/environment

    if [[ -d /run/openrc ]]; then
        sed -i "s/keymap=.*/keymap=\"${keytable}\"/" /etc/conf.d/keymaps
    fi
    echo "KEYMAP=${keytable}" > /etc/vconsole.conf
    echo "LANG=${lang}.UTF-8" > /etc/locale.conf
    ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime

    write_x11_config

    loadkeys "${keytable}"

    locale-gen ${lang}
    echo "Configured language: ${lang}" >> "${LOGFILE}"
    echo "Configured keymap: ${keytable}" >> "${LOGFILE}"
    echo "Configured timezone: ${timezone}" >> "${LOGFILE}"
}

configure_calamares(){
    if [[ -f /usr/bin/calamares ]];then
        netinstall=$(get_cal_mode)
        if [[ "${netinstall}" == 'no' ]];then
            sed -e "/- netinstall/d" \
                -e "s|- chrootcfg|- unpackfs|" -i /etc/calamares/settings.conf

            sed -e '$ d' -i /etc/calamares/modules/welcome.conf
        fi
    fi
}

configure_sudoers_d(){
    echo "%wheel  ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/g_wheel
    echo "root ALL=(ALL) ALL"  > /etc/sudoers.d/u_root
}

configure_swap(){
    local swapdev="$(fdisk -l 2>/dev/null | grep swap | cut -d' ' -f1)"
    if [ -e "${swapdev}" ]; then
        swapon ${swapdev}
    fi
}

configure_user_root(){
    # set up root password
    echo "root:${password}" | chroot $1 chpasswd
    cp /etc/skel/.{bash_profile,bashrc,bash_logout} /root/
}
