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


UEFI_BIOS_TEXT=
INSTALL_DEVICE=
MIRRORLIST_COUNTRIES=()
LANGUAGES=()
ZONE=
SUBZONE=
HOSTNAME="archlinux"
ROOT_PASSWORD=
USER_NAME="arch"
USER_PASSWORD="123456"

function select_mirrorlist() {
    print_title "MIRRORLIST - https://wiki.dex.php/Mirrors"
    print_info "This option is a guide to selecting and configuring your mirrors, and a listing of current available mirrors."

    local countries_code=("AU" "AT" "BY" "BE" "BR" "BG" "CA" "CL" "CN" "CO" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HK" "HU" "ID" "IN" "IR" "IE" "IL" "IT" "JP" "KZ" "KR" "LV" "LU" "MK" "NL" "NC" "NZ" "NO" "PL" "PT" "RO" "RU" "RS" "SG" "SK" "ZA" "ES" "LK" "SE" "CH" "TW" "TR" "UA" "GB" "US" "UZ" "VN")
    local countries_name=("Australia" "Austria" "Belarus" "Belgium" "Brazil" "Bulgaria" "Canada" "Chile" "China" "Colombia" "Czech Republic" "Denmark" "Estonia" "Finland" "France" "Germany" "Greece" "Hong Kong" "Hungary" "Indonesia" "India" "Iran" "Ireland" "Israel" "Italy" "Japan" "Kazakhstan" "Korea" "Latvia" "Luxembourg" "Macedonia" "Netherlands" "New Caledonia" "New Zealand" "Norway" "Poland" "Portugal" "Romania" "Russia" "Serbia" "Singapore" "Slovakia" "South Africa" "Spain" "Sri Lanka" "Sweden" "Switzerland" "Taiwan" "Turkey" "Ukraine" "United Kingdom" "United States" "Uzbekistan" "Viet Nam")

    PS3=${PROMPT_2}
    echo -e "Select your country:\n"
    select v in ${countries_name[@]}; do
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
        break
    done
    
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

function set_hostname() {
    local result
    read -p "Input your Hostname[ex: ${HOSTNAME}}]: " result
    if [[ ! -z ${result} ]]; then 
        HOSTNAME=${result}
    fi
}

function set_root_password() {
    set_password root ROOT_PASSWORD
    if [[ ! ${ROOT_PASSWORD} ]]; then
        return 1
    fi
}

function set_login_user() {
    local result
    read -p "Input login user name[ex: ${USER_NAME}]: " result
    if [[ ! -z ${result} ]]; then 
        USER_NAME=${result}
    fi
    
    set_password ${USER_NAME} USER_PASSWORD ${USER_PASSWORD}
}

print_title "https://wiki.archlinux.org/index.php/Arch_Install_Scripts"
print_info "The Arch Install Scripts are a set of Bash scripts that simplify Arch installation."
pause
checklist=( 0 0 0 0 0 0 0 )
while true; do
    print_title "ARCHLINUX ULTIMATE INSTALL - https://github.com/vastpeng/aui"
    echo " ${UEFI_BIOS_TEXT:=Boot Not Detected}"
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
            "q") exit 0;;
            *) invalid_option;;
        esac
    done
done
