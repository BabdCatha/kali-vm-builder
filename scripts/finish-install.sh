#!/bin/sh

# The reference version of this script is maintained in:
#   kali-installer/simple-cdd/profiles/kali.postinst
#   kali-live/kali-config/common/includes.installer/kali-finish-install
#   kali-live/kali-config/common/includes.chroot/usr/lib/live/config/0031-kali-user-setup
#   kali-vm/scripts/finish-install.sh
# (sometimes with small variations)
#
# This script MUST be idempotent.

set -e

configure_apt_sources_list() {
    # make sources.list empty, to force setting defaults
    echo > /etc/apt/sources.list

    if grep -q '^deb ' /etc/apt/sources.list; then
        echo "INFO: sources.list is configured, everything is fine"
        return
    fi

    echo "INFO: sources.list is empty, setting up a default one for Kali"

    cat >/etc/apt/sources.list <<END
# See https://www.kali.org/docs/general-use/kali-linux-sources-list-repositories/
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware

# Additional line for source packages
# deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
END
    apt-get update
}

get_user_list() {
    for user in $(cd /home && ls); do
        if ! getent passwd "$user" >/dev/null; then
            echo "WARNING: user '$user' is invalid but /home/$user exists" >&2
            continue
        fi
        echo "$user"
    done
    echo "root"
}

configure_zsh() {
    if grep -q 'nozsh' /proc/cmdline; then
        echo "INFO: user opted out of zsh by default"
        return
    fi
    if [ ! -x /usr/bin/zsh ]; then
        echo "INFO: /usr/bin/zsh is not available"
        return
    fi
    for user in $(get_user_list); do
        echo "INFO: changing default shell of user '$user' to zsh"
        chsh --shell /usr/bin/zsh $user
    done
}

configure_usergroups() {
    # Ensure those groups exist
    addgroup --system kaboxer || true
    addgroup --system wireshark || true

    # adm - read access to log files
    # dialout - for serial access
    # kaboxer - for kaboxer
    # sudo - be root
    # vboxsf - shared folders for virtualbox guest
    # wireshark - capture sessions in wireshark
    kali_groups="adm dialout kaboxer sudo vboxsf wireshark"

    for user in $(get_user_list | grep -xv root); do
        echo "INFO: adding user '$user' to groups '$kali_groups'"
    	for grp in $kali_groups; do
    	    getent group $grp >/dev/null || continue
    	    usermod -a -G $grp $user
    	done
    done
}

pkg_installed() {
    dpkg -s "$1" 2>/dev/null | grep -q "ok installed"
}

configure_terminal() {
    while read -r desktop terminal; do
        pkg_installed kali-desktop-$desktop || continue
        echo "INFO: setting x-terminal-emulator alternative to '$terminal'"
        update-alternatives --verbose --set x-terminal-emulator /usr/bin/$terminal || true
        break
    done <<END
e17   terminology
gnome gnome-terminal.wrapper
i3    kitty
kde   konsole
lxde  lxterminal
mate  mate-terminal.wrapper
xfce  qterminal
END
}

configure_etc_hosts() {
    hostname=$(cat /etc/hostname)

    if grep -Eq "^127\.0\.1\.1\s+$hostname" /etc/hosts; then
        echo "INFO: hostname already present in /etc/hosts"
        return
    fi

    if ! grep -Eq "^127\.0\.0\.1\s+localhost" /etc/hosts; then
        echo "ERROR: couldn't find localhost in /etc/hosts"
        exit 1
    fi

    echo "INFO: adding line '127.0.1.1 $hostname' to /etc/hosts"
    sed -Ei "/^127\.0\.0\.1\s+localhost/a 127.0.1.1\t$hostname" /etc/hosts
}

save_debconf() {
    # save values for keyboard-configuration, otherwise debconf will
    # ask to configure the keyboard when the package is upgraded.
    if pkg_installed keyboard-configuration; then
        DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
            dpkg-reconfigure keyboard-configuration
    fi
}

while [ $# -ge 1 ]; do
    case $1 in
        apt-sources) configure_apt_sources_list ;;
        debconf)     save_debconf ;;
        etc-hosts)   configure_etc_hosts ;;
        terminal)    configure_terminal ;;
        usergroups)  configure_usergroups ;;
        zsh)         configure_zsh ;;
        *) echo "ERROR: Unsupported argument '$1'"; exit 1 ;;
    esac
    shift
done
