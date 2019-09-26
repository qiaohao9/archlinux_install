#!/bin/bash

# COLORS {{{
    Bold=$(tput bold)
    Reset=$(tput sgr0)

    Red=$(tput setaf 1)
    Yellow=$(tput setaf 3)

    BRed=${Bold}${Red}
    BYellow=${Bold}${Yellow}
#}}}
# PROMPTS {{{
    PROMPT_2="Enter n° of options (ex: 1 2 3 or 1-3): "
    PROMPT_1="Enter your option: "
#}}}

function print_line() {
    printf "%$(tput cols)s\n" | tr ' ' '-'
}

function print_error() { 
    T_COLS=`tput cols`
    echo -e "\n\n${BRed}$1${Reset}\n" | fold -sw $(( $T_COLS - 1 ))
    sleep 3
    return 1
}

function print_title() {
    clear
    print_line
    echo -e "# ${Bold}$1${Reset}"
    print_line
    echo ""
}

function pause() {
    print_line
    read -e -sn 1 -p "Press enter to continue..."
}

function print_info() {
    T_COLS=`tput cols`
    echo -e "${Bold}$1${Reset}\n" | fold -sw $(( $T_COLS - 18)) | sed 's/^/\t/'
}

function checkbox() { 
    #display [X] or [ ]
    [[ "$1" -eq 1 ]] && echo -e "${BBlue}[${Reset}${Bold}X${BBlue}]${Reset}" || echo -e "${BBlue}[ ${BBlue}]${Reset}";
}

function mainmenu_item() { 
    #if the task is done make sure we get the state
    if  [[ $3 != "" ]] && [[ $3 != "/" ]]; then    
        state="${BGreen}[${Reset}$3${BGreen}]${Reset}"
    else
        state="${BGreen}[${Reset}Not Set${BGreen}]${Reset}"
    fi
    echo -e "$(checkbox "$1") ${Bold}$2${Reset} ${state}"
} 

function invalid_option() {
    print_line
    echo "${BRed}Invalid option, Try another one.${Reset}"
    pause
}

function read_input_options() {
    local line
    local packages

    if [[ ! $@ ]]; then
        read -p "${PROMPT_2}" OPTION
    else
        OPTION=$@
    fi
    array=(${OPTION})

    for line in ${array[@]/,/ }; do
        if [[ ${line/-/} != ${line} ]]; then
            for (( i=${line%-*}; i <= ${line#*-}; i++ )); do
                packages+={$i};
            done
        else
            packages+=($line)
        fi
    done

    OPTIONS=(${packages[@]})
}

function contains_element() {
    for e in in "${@:2}"; do [[ ${e} == ${1} ]] && break; done;
}

function unique_elements() {
    RESULT_UNIQUE_ELEMENTS=($(echo $@ | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

function confirm_operation() {
    read -p "${BYellow}$1 [y/N]: ${Reset}" OPTION
    OPTION=`echo "${OPTION}" | tr '[:upper:]' '[:lower:]'`    
}


function set_password() {
    while true; do
        read -s -p "Password for $1: " password1
        echo
        read -s -p "Confirm the password: " password2
        echo
        if [[ ${password1} == ${password2} ]]; then
            eval $2=${password1}
            break
        fi
        echo "Please try again"
    done 
}

function arch_chroot() {
    arch-chroot $MOUNT_POINT /bin/bash -c "${1}"
}


UEFI_BIOS_TEXT="Boot Not Detected"
INSTALL_DEVICE=
MIRRORLIST_COUNTRIES=()
RANK_MIRRORS=0
LANGUAGES=()
ZONE=
SUBZONE=
HOSTNAME="archlinux"
ROOT_PASSWORD=
USER_NAME="arch"
USER_PASSWORD="123456"

MOUNT_POINT="/mnt"

function select_mirrorlist() {
    print_title "MIRRORLIST - https://wiki.dex.php/Mirrors"
    print_info "This option is a guide to selecting and configuring your mirrors, and a listing of current available mirrors."

    local countries_code=("AU" "AT" "BY" "BE" "BR" "BG" "CA" "CL" "CN" "CO" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HK" "HU" "ID" "IN" "IR" "IE" "IL" "IT" "JP" "KZ" "KR" "LV" "LU" "MK" "NL" "NC" "NZ" "NO" "PL" "PT" "RO" "RU" "RS" "SG" "SK" "ZA" "ES" "LK" "SE" "CH" "TW" "TR" "UA" "GB" "US" "UZ" "VN")
    local countries_name=("Australia" "Austria" "Belarus" "Belgium" "Brazil" "Bulgaria" "Canada" "Chile" "China" "Colombia" "Czech Republic" "Denmark" "Estonia" "Finland" "France" "Germany" "Greece" "Hong Kong" "Hungary" "Indonesia" "India" "Iran" "Ireland" "Israel" "Italy" "Japan" "Kazakhstan" "Korea" "Latvia" "Luxembourg" "Macedonia" "Netherlands" "New Caledonia" "New Zealand" "Norway" "Poland" "Portugal" "Romania" "Russia" "Serbia" "Singapore" "Slovakia" "South Africa" "Spain" "Sri Lanka" "Sweden" "Switzerland" "Taiwan" "Turkey" "Ukraine" "United Kingdom" "United States" "Uzbekistan" "Viet Nam")

    PS3=${PROMPT_2}
    echo -e "Select your country:\n"
    select v in "${countries_name[@]}"; do
        read_input_options $REPLY
        for OPT in ${OPTIONS[@]}; do
            country_code=${countries_code[$(( $OPT - 1 ))]}
            if [[ ${country_code} ]]; then
                MIRRORLIST_COUNTRIES=( ${country_code} ${MIRRORLIST_COUNTRIES[@]} )
            fi
        done

        unique_elements ${MIRRORLIST_COUNTRIES[@]}
        MIRRORLIST_COUNTRIES=( ${RESULT_UNIQUE_ELEMENTS[@]} )
        if [[ ${#MIRRORLIST_COUNTRIES} -eq 0 ]]; then
            return 1
        fi

        confirm_operation "DO you want to rank mirrors?"
        if [[ ${OPTION} == "y" ]]; then
            RANK_MIRRORS=1
        fi
        break
    done
    
}

function configure_mirrorlist() {
    local params=""
    for country in ${MIRRORLIST_COUNTRIES[@]}; do
        params+="country=${country}&"
    done
    url="https://www.archlinux.org/mirrorlist/?${params}protocol=http&protocol=https&ip_version=4&ip_version=6"

    # Get latest mirror list and save to tmpfile
    tmpfile=$(mktemp --suffix=-mirrorlist)
    curl -Lo ${tmpfile} ${url}
    sed -i 's/^#Server/Server/g' ${tmpfile}

    # Backup and replace current mirrorlist file (if new file is non-zero)
    if [[ -s ${tmpfile} ]]; then
        { echo " Backing up the original mirrorlist..."
            mv -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig; } &&
        { echo " Rotating the new list into place..."
            mv -f ${tmpfile} /etc/pacman.d/mirrorlist; }
    else
        print_error " Unable to update, could not download list."
    fi

    if [[ ${RANK_MIRRORS} -eq 1 ]]; then
        pacman -S pacman-contrib --noconfirm
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.tmp
        print_info "Next, Ranking mirrors will take a so long time, wait..."
        rankmirrors /etc/pacman.d/mirrorlist.tmp > /etc/pacman.d/mirrorlist
        rm /etc/pacman.d/mirrorlist.tmp
    fi
}

function select_device() {
    local devices_list=(`lsblk -d | awk 'NR>1 { print "/dev/" $1 }'`)
    PS3=${PROMPT_1}
    echo -e "Select device to install Arch Linux:\n"
    select device in "${devices_list[@]}"; do
        if contains_element ${device} ${devices_list[@]}; then 
            confirm_operation "Data on ${device} will be damaged"
            break
        else
            invalid_option
        fi
    done

    if [[ ${OPTION} == "y" ]]; then
        INSTALL_DEVICE=${device}
        return 0
    fi

    return 1
}

function format_devices() {
    # TODO 
    # Support LVM?
    sgdisk --zap-all ${INSTALL_DEVICE}
    local boot_partion="${INSTALL_DEVICE}1"
    local system_partion="${INSTALL_DEVICE}2"

    [[ ${UEFI_BIOS_TEXT} == "Boot Not Detected" ]] && print_error "Boot method isn't be detected!"
    [[ ${UEFI_BIOS_TEXT} == "UEFI detected" ]] && printf "n\n1\n\n+512M\nef00\nw\ny\n" | gdisk ${INSTALL_DEVICE} && yes | mkfs.fat -F32 ${boot_partion}
    [[ ${UEFI_BIOS_TEXT} == "BIOS detected" ]] && printf "n\n1\n\n+2M\nef02\nw\ny\n" | gdisk ${INSTALL_DEVICE} && yes | mkfs.ext2 ${boot_partion}

    printf "n\n2\n\n\n8300\nw\ny\n"| gdisk ${INSTALL_DEVICE}
    yes | mkfs.ext4 ${system_partion}

    mount ${system_partion} /mnt
    [[ ${UEFI_BIOS_TEXT} -eq "UEFI detected" ]] && mkdir -p /mnt/boot/efi && mount ${boot_partion} /mnt/boot/efi
}

function select_timezone() {
    print_title "HARDWARE CLOCK TIME - https://wiki.archlinux.org/index.php/Internationalization"
    print_info "This is set in /etc/adjtime. Set the hardware clock mode uniformly between your operating systems on the same machine. Otherwise, they will overwrite the time and cause clock shifts (which can cause time drift correction to be miscalibrated)."

    local timezones=(`timedatectl list-timezones | sed 's/\/.*$//' | uniq`)
    PS3=${PROMPT_1}
    echo -e "Select zone:\n"
    select ZONE in ${timezones[@]}; do
        if contains_element ${ZONE} ${timezones[@]}; then
            local _subzones=(`timedatectl list-timezones | grep ${ZONE} | sed 's/^.*\///'`)
            PS3="${PROMPT_1}"
            echo "Select subzone:"
            select SUBZONE in "${_subzones[@]}"; do
                if contains_element "$SUBZONE" "${_subzones[@]}"; then
                    break
                else
                    invalid_option
                fi
            done
            break
        else
            invalid_option
        fi
    done
}

function configure_timezone() {
    print_title "TIMEZONE - https://wiki.archlinux.org/index.php/Timezone"
    print_info "In an operating system the time (clock) is determined by four parts: Time value, Time standard, Time Zone, and DST (Daylight Saving Time if applicable)."

    arch_chroot "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
    arch_chroot "sed -i '/#NTP=/d' /etc/systemd/timesyncd.conf"
    arch_chroot "sed -i 's/#Fallback//' /etc/systemd/timesyncd.conf"
    arch_chroot "echo \"FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 0.fr.pool.ntp.org\" >> /etc/systemd/timesyncd.conf"
    arch_chroot "systemctl enable systemd-timesyncd.service"
    arch_chroot "hwclock --systohc --localtime"
}

function select_languages() {
    print_title "LOCALE - https://wiki.archlinux.org/index.php/Locale"
    print_info "Locales are used in Linux to define which language the user uses. As the locales define the character sets being used as well, setting up the correct locale is especially important if the language contains non-ASCII characters."

    local languages=(`cat /etc/locale.gen | grep UTF-8 | sed 's/\..*$//' | sed '/@/d' | awk '{print $1}' | uniq | sed 's/#//g'`);
    PS3=${PROMPT_2}
    echo -e "Select locale:\n"
    select v in "${languages[@]}" Done; do
        read_input_options $REPLY
        for OPT in ${OPTIONS[@]}; do
            language=${languages[$(( ${OPT} - 1 ))]}
            if [[ ${language} ]]; then
                LANGUAGES=( "${language}.UTF-8" ${LANGUAGES[@]})
            fi
        done

        unique_elements ${LANGUAGES[@]}
        LANGUAGES=( ${RESULT_UNIQUE_ELEMENTS[@]} )
        if [[ ${#LANGUAGES} -eq 0 ]]; then
            return 1
        fi
        break
    done
}

function configure_languages() {
    local languages_utf8=""
    for languages in ${LANGUAGES[@]}; do
        languages_utf8+="${languages} "
        arch_chroot "sed -i 's/#\('${languages}'\)/\1/' /etc/locale.gen"
    done

    echo "LANG=${LANG}" > ${MOUNT_POINT}/etc/locale.conf
    arch_chroot "locale-gen"
}

function set_hostname() {
    local result
    read -p "Input your Hostname[ex: ${HOSTNAME}}]: " result
    if [[ ! -z ${result} ]]; then 
        HOSTNAME=${result}
    fi
}

function configure_hostname() {
    if [[ -e "${MOUNT_POINT}/etc/hostname" ]]; then 
        mv  -f "${MOUNT_POINT}/etc/hostname" "${MOUNT_POINT}/etc/hostname.orig" 
    fi
    if [[ -e "${MOUNT_POINT}/etc/hosts" ]]; 
        then mv  -f "${MOUNT_POINT}/etc/hosts" "${MOUNT_POINT}/etc/hosts.orig" 
    fi

    echo "{$HOSTNAME}" > ${MOUNT_POINT}/etc/hostname

    arch_chroot "echo '127.0.0.1  localhost ${HOSTNAME} ${HOSTNAME}.localdomain' >> /etc/hosts"
    arch_chroot "echo '::1        localhost ${HOSTNAME} ${HOSTNAME}.localdomain' >> /etc/hosts"
}

function set_root_password() {
    set_password root ROOT_PASSWORD
    if [[ ! ${ROOT_PASSWORD} ]]; then
        return 1
    fi
}

function configure_user() {
    arch_chroot 'echo "root:${ROOT_PASSWORD}" | chpasswd'
    arch_chroot 'useradd -m -s $(which zsh) -G wheel ${USER_NAME} && echo "${USER_PASSWORD}:${USER_PASSWORD}" | chpasswd'
}

function set_login_user() {
    local result
    read -p "Input login user name[ex: ${USER_NAME}]: " result
    if [[ ! -z ${result} ]]; then 
        USER_NAME=${result}
    fi
    
    set_password ${USER_NAME} USER_PASSWORD ${USER_PASSWORD}
}

function uefi_bios_detect() {
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
        modprobe -r -q efivars || true  # if MAC
    else
        modprobe -q efivarfs            # all others
    fi

    if [[ -d "/sys/firmware/efi/" ]]; then
        ## Mount efivarfs if it is not already mounted
        if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
            mount -t efivarfs efivarfs /sys/firmware/efi/efivars
        fi
        UEFI_BIOS_TEXT="UEFI detected"
    else
        UEFI_BIOS_TEXT="BIOS detected"
    fi
}

function bootloader_uefi() {
    arch_chroot "pacman -S efibootmgr --noconfirm"
    arch_chroot "grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi"
    arch_chroot "mkdir /boot/efi/EFI/BOOT"
    arch_chroot "cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI"
    arch_chroot "echo 'bcf boot add 1 fs0:\EFI\grubx64.efi \"My GRUB bootloader\" && exit' > /boot/efi/startup.sh"
    arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
}

function bootloader_bios() {
    arch_chroot "grub-install ${INSTALL_DEVICE}2"
    arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
}

function bootloader_install() {
    case ${UEFI_BIOS_TEXT} in
        "UEFI detected") bootloader_uefi;;
        "BIOS detected") bootloader_bios;;
        *) print_error "Bootloader isn't detected.";;
    esac
}


function system_install() {
    format_devices
    configure_mirrorlist

    # Install system-base
    yes '' | pacstrap -i /mnt base base-devel grub os-prober git zsh neovim 
    yes '' | genfstab -U /mnt >> /mnt/etc/fstab

    configure_timezone
    configure_hostname
    configure_user

    bootloader_install
}

function install() {
    confirm_operation "Operation is irreversible, Are you sure?"
    if [[ ${OPTION} = "y" ]]; then
        system_install
    else
        return
    fi
}

print_title "https://wiki.archlinux.org/index.php/Arch_Install_Scripts"
print_info "The Arch Install Scripts are a set of Bash scripts that simplify Arch installation."
uefi_bios_detect
pause
checklist=( 0 0 0 0 0 0 0 )
while true; do
    print_title "ARCHLINUX ULTIMATE INSTALL - https://github.com/vastpeng/archlinux_install"
    echo " ${UEFI_BIOS_TEXT}"
    echo ""
    echo " 1) $(mainmenu_item "${checklist[1]}"  "Select Mirrors"             "${MIRRORLIST_COUNTRIES[*]}" )"
    echo " 2) $(mainmenu_item "${checklist[2]}"  "Select Device"              "${INSTALL_DEVICE}" )"
    echo " 3) $(mainmenu_item "${checklist[3]}"  "Select Timezone"            "${ZONE}/${SUBZONE}" )"
    echo " 4) $(mainmenu_item "${checklist[4]}"  "Select Locale-UTF8"         "${LANGUAGES[*]}" )"
    echo " 5) $(mainmenu_item "${checklist[5]}"  "Set Hostname"               "${HOSTNAME}" )"
    echo " 6) $(mainmenu_item "${checklist[6]}"  "Set Root Password"          "${ROOT_PASSWORD}" )"
    echo " 7) $(mainmenu_item "${checklist[7]}"  "Set Login User"             "${USER_NAME}/${USER_PASSWORD}" )"
    echo ""
    echo " i) install"
    echo " q) quit"
    echo ""

    read_input_options
    for OPT in ${OPTIONS[@]}; do
        case ${OPT} in
            1) select_mirrorlist && checklist[1]=1;;
            2) select_device && checklist[2]=1;;
            3) select_timezone && checklist[3]=1;;
            4) select_languages && checklist[4]=1;;
            5) set_hostname && checklist[5]=1;;
            6) set_root_password && checklist[6]=1;;
            7) set_login_user && checklist[7]=1;;
            "i") install;;
            "q") exit 0;;
            *) invalid_option;;
        esac
    done
done
