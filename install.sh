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

    read -p "${PROMPT_2}" OPTION
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

function confirm_operation() {
    read -p "${BYellow}$1 [y/N]: ${Reset}" OPTION
    OPTION=`echo "${OPTION}" | tr '[:upper:]' '[:lower:]'`    
}


UEFI_BIOS_TEXT=

function select_mirrorlist() {
    print_title "MIRRORLIST - https://wiki.dex.php/Mirrors"
    print_info "This option is a guide to selecting and configuring your mirrors, and a listing of current available mirrors."

    local countries_code=("AU" "AT" "BY" "BE" "BR" "BG" "CA" "CL" "CN" "CO" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HK" "HU" "ID" "IN" "IR" "IE" "IL" "IT" "JP" "KZ" "KR" "LV" "LU" "MK" "NL" "NC" "NZ" "NO" "PL" "PT" "RO" "RU" "RS" "SG" "SK" "ZA" "ES" "LK" "SE" "CH" "TW" "TR" "UA" "GB" "US" "UZ" "VN")
    local countries_name=("Australia" "Austria" "Belarus" "Belgium" "Brazil" "Bulgaria" "Canada" "Chile" "China" "Colombia" "Czech Republic" "Denmark" "Estonia" "Finland" "France" "Germany" "Greece" "Hong Kong" "Hungary" "Indonesia" "India" "Iran" "Ireland" "Israel" "Italy" "Japan" "Kazakhstan" "Korea" "Latvia" "Luxembourg" "Macedonia" "Netherlands" "New Caledonia" "New Zealand" "Norway" "Poland" "Portugal" "Romania" "Russia" "Serbia" "Singapore" "Slovakia" "South Africa" "Spain" "Sri Lanka" "Sweden" "Switzerland" "Taiwan" "Turkey" "Ukraine" "United Kingdom" "United States" "Uzbekistan" "Viet Nam")

    PS3=${PROMPT_2}
    echo "Select your country:"

}

print_title "https://wiki.archlinux.org/index.php/Arch_Install_Scripts"
print_info "The Arch Install Scripts are a set of Bash scripts that simplify Arch installation."
pause
checklist=( 0 0 0 0 0 0 0 )
while true; do
    print_title "ARCHLINUX ULTIMATE INSTALL - https://github.com/vastpeng/aui"
    echo " ${UEFI_BIOS_TEXT:=Boot Not Detected}"
    echo ""
    echo " 1) $(mainmenu_item "${checklist[1]}"  "Select Mirrors"             "${country_codes[*]}" )"
    echo " 2) $(mainmenu_item "${checklist[2]}"  "Select Device"              "${install_device}" )"
    echo " 3) $(mainmenu_item "${checklist[3]}"  "Select Timezone"            "${ZONE}/${SUBZONE}" )"
    echo " 4) $(mainmenu_item "${checklist[4]}"  "Select Locale-UTF8"         "${locale_utf8[*]}" )"
    echo " 5) $(mainmenu_item "${checklist[5]}"  "Configure Hostname"         "${host_name}" )"
    echo " 6) $(mainmenu_item "${checklist[6]}"  "Root password"              "${root_password}" )"
    echo " 7) $(mainmenu_item "${checklist[7]}"  "Set Usesr Info"             "${user_name}/${user_password}" )"
    echo ""
    echo " i) install"
    echo " q) quit"
    echo ""

    read_input_options
    for OPT in ${OPTIONS[@]}; do
        case ${OPT} in
            "q") exit 0;;
            *) invalid_option;;
        esac
    done
done
