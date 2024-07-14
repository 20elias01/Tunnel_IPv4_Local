#!/bin/bash
#
# Tunnel_IPv4Local.sh
# Author: github.com/20elias01
#
# This script is designed to simplify the configuration of a
# IPv4 tunnel . It provides options to
# install required packages, configure the remote and local servers, and
# uninstall the configuration and Restarting Services.
#
# Supported operating systems: Tested on Ubuntu 22.04 - Hetznet
# Disclaimer:
# This script comes with no warranties or guarantees. Use it at your own risk.

# Default values
DEFAULT_TUNNEL_NAME="EliasTunnel"
DEFAULT_PORT="2090"
LOG_FILE="/var/log/tunnel_ipv6local.log"

# Define colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD_BLACK='\033[1;30m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_PURPLE='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_PURPLE='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'
LIGHT_GREEN='\033[1;32m'
DARK_GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Define a function to colorize text
colorize() {
    local color="$1"
    local text="$2"
    local style="${3:-normal}"
    
    # Define ANSI color codes
    local black="\033[30m"
    local red="\033[31m"
    local green="\033[32m"
    local yellow="\033[33m"
    local blue="\033[34m"
    local magenta="\033[35m"
    local cyan="\033[36m"
    local white="\033[37m"
    local reset="\033[0m"
    
    # Define ANSI style codes
    local normal="\033[0m"
    local bold="\033[1m"
    local underline="\033[4m"
    # Select color code
    local color_code
    case $color in
        black) color_code=$black ;;
        red) color_code=$red ;;
        green) color_code=$green ;;
        yellow) color_code=$yellow ;;
        blue) color_code=$blue ;;
        magenta) color_code=$magenta ;;
        cyan) color_code=$cyan ;;
        white) color_code=$white ;;
        *) color_code=$reset ;;  # Default case, no color
    esac
    # Select style code
    local style_code
    case $style in
        bold) style_code=$bold ;;
        underline) style_code=$underline ;;
        normal | *) style_code=$normal ;;  # Default case, normal text
    esac

    # Print the colored and styled text
    echo -e "${style_code}${color_code}${text}${reset}"
}

# Log function
log() {
    echo "$(date +"%Y-%m-%d %T") - $1" | tee -a "$LOG_FILE"
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo -e "\e[93mThis script must be run as root. Please use sudo -i.\e[0m"
  exit 1
fi

# Function to install unzip if not already installed
install_unzip() {
    if ! command -v unzip &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${BG_GREEN}unzip is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y unzip
        else
            echo -e "${RED}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

install_easytier() {
    # Define the directory and files
    DEST_DIR="/root/easytier"
    FILE1="easytier-core"
    FILE2="easytier-cli"
    URL_X86="https://github.com/EasyTier/EasyTier/releases/download/v1.1.0/easytier-x86_64-unknown-linux-musl-v1.1.0.zip"
    URL_ARM_SOFT="https://github.com/EasyTier/EasyTier/releases/download/v1.1.0/easytier-armv7-unknown-linux-musleabi-v1.1.0.zip"              
    URL_ARM_HARD="https://github.com/EasyTier/EasyTier/releases/download/v1.1.0/easytier-armv7-unknown-linux-musleabihf-v1.1.0.zip"
    
    
    # Check if the directory exists
    if [ -d "$DEST_DIR" ]; then    
        # Check if the files exist
        if [ -f "$DEST_DIR/$FILE1" ] && [ -f "$DEST_DIR/$FILE2" ]; then
            colorize green "EasyMesh Core Installed" bold
            return 0
        fi
    fi
    
    # Detect the system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        URL=$URL_X86
        ZIP_FILE="/root/easytier/easytier-x86_64-unknown-linux-musl-v1.1.0.zip"
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "aarch64" ]; then
        if [ "$(ldd /bin/ls | grep -c 'armhf')" -eq 1 ]; then
            URL=$URL_ARM_HARD
            ZIP_FILE="/root/easytier/easytier-armv7-unknown-linux-musleabihf-v1.1.0.zip"
        else
            URL=$URL_ARM_SOFT
            ZIP_FILE="/root/easytier/easytier-armv7-unknown-linux-musleabi-v1.1.0.zip"
        fi
    else
        colorize red "Unsupported architecture: $ARCH\n" bold
        return 1
    fi


    colorize yellow "Installing EasyMesh Core...\n" bold
    mkdir -p $DEST_DIR &> /dev/null
    curl -L $URL -o $ZIP_FILE &> /dev/null
    unzip $ZIP_FILE -d $DEST_DIR &> /dev/null
    rm $ZIP_FILE &> /dev/null

    if [ -f "$DEST_DIR/$FILE1" ] && [ -f "$DEST_DIR/$FILE2" ]; then
        colorize green "EasyMesh Core Installed Successfully...\n" bold
        sleep 1
        return 0
    else
        colorize red "Failed to install EasyMesh Core...\n" bold
        return 1
    fi
}

# Call the functions
install_unzip
install_easytier

# Var
EASY_CLIENT='/root/easytier/easytier-cli'
SERVICE_FILE="/etc/systemd/system/easymesh.service"

# Function to display local IP address from tunnel information
display_local_ip() {
    SERVICE_FILE="/etc/systemd/system/easymesh.service"
    if [[ ! -f $SERVICE_FILE ]]; then
        :
    else
        exec_start=$(grep -oP '(?<=ExecStart=).+' "$SERVICE_FILE" | head -n 1)
        local_ip=$(echo "$exec_start" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
        echo -e "                       ${BOLD_YELLOW}Current Local IP Address${NC}: ${BOLD_PURPLE}$local_ip${NC}
        "
    fi
}

# function of Tunnel service does not exist.
not_exist() {
            echo -e "
                                
                                
                            ${BOLD_RED}Tunnel service does not exist.${NC}

                            ${RED}Tunnel service does not exist.${NC}

                            ${BOLD_RED}Tunnel service does not exist.${NC}

                            ${RED}Tunnel service does not exist.${NC}

                            ${BOLD_RED}Tunnel service does not exist.${NC}

                            ${RED}Tunnel service does not exist.${NC}

                            ${BOLD_RED}Tunnel service does not exist.${NC}

                            ${RED}Tunnel service does not exist.${NC}

                            ${BOLD_RED}Tunnel service does not exist.${NC}

                            ${RED}Tunnel service does not exist.${NC}"
}

# Function to display ASCII art
display_ascii_art() {
    clear
    local COLORS=("\033[31m" "\033[91m" "\033[33m" "\033[93m" "\033[32m" "\033[36m" "\033[34m" "\033[35m")
    local NC="\033[0m"  # No Color

    local num_colors=${#COLORS[@]}
    local line_num=0

    while IFS= read -r line; do
        local color_index=$((line_num % num_colors))
        echo -e "${COLORS[color_index]}$line${NC}"
        ((line_num++))
    done << "EOF"
            ██████████    █████           ███                                    
           ░░███░░░░░█   ░░███           ░░░                                     
            ░███  █ ░     ░███           ████      ██████       █████            
            ░██████       ░███          ░░███     ░░░░░███     ███░░             
            ░███░░█       ░███           ░███      ███████    ░░█████            
            ░███ ░   █    ░███      █    ░███     ███░░███     ░░░░███           
            ██████████    ███████████    █████   ░░████████    ██████            
           ░░░░░░░░░░    ░░░░░░░░░░░    ░░░░░     ░░░░░░░░    ░░░░░░           

                  █████   █████    ███████████     ██████   █████                
                 ░░███   ░░███    ░░███░░░░░███   ░░██████ ░░███                 
                  ░███    ░███     ░███    ░███    ░███░███ ░███                 
                  ░███    ░███     ░██████████     ░███░░███░███                 
                  ░░███   ███      ░███░░░░░░      ░███ ░░██████                 
                   ░░░█████░       ░███            ░███  ░░█████                 
                     ░░███         █████           █████  ░░█████                
                      ░░░         ░░░░░           ░░░░░    ░░░░░                 

EOF
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to generate a random IPv4 address
generate_random_ip() {
    local octet4=$(( RANDOM % 144 + 1 ))  
    echo "10.144.144.$octet4"
}
# Generate a random IP address
RANDOM_IP=$(generate_random_ip)

# Function to Create New IPv4Tunnel
Create_New_IPv4Tunnel() {
    clear

    read -p "$(echo -e "${BOLD_GREEN}Enter your Destination IP [ IP Maghsad ] : ${NC}")" Destination_IP
    while ! validate_ip "$Destination_IP"; do
        echo "Invalid IP format. Please enter a valid IP address."
        read -p "$(echo -e "${BOLD_GREEN}Enter your Destination IP [IP Maghsad] : ${NC}")" Destination_IP
    done

    read -p "$(echo -e "${BOLD_YELLOW}Enter your Local IP [${RANDOM_IP}] : ${NC}")" Local_IP
    if [[ ! "$Local_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${BOLD_YELLOW}Using default Local IP.${NC}"
        Local_IP=$RANDOM_IP
    fi


    read -p "$(echo -e "${BOLD_RED}Enter your Tunnel Port [${DEFAULT_PORT}] : ${NC}")" Tunnel_Port
    if ! [[ "$Tunnel_Port" =~ ^[0-9]+$ ]]; then
        Tunnel_Port=$DEFAULT_PORT
    fi

    read -p "$(echo -e "${BOLD_CYAN}Enter your Tunnel Name [${DEFAULT_TUNNEL_NAME}] : ${NC}")" Tunnel_Name
    Tunnel_Name=${Tunnel_Name:-$DEFAULT_TUNNEL_NAME}

    # Create the systemd service file
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=EasyMesh Network Service
After=network.target

[Service]
ExecStart=/root/easytier/easytier-core -i ${Local_IP} --peers tcp://${Destination_IP}:${Tunnel_Port} --hostname ${Tunnel_Name} --network-secret b2537eb2858e --default-protocol tcp --listeners tcp://[::]:${Tunnel_Port} tcp://0.0.0.0:${Tunnel_Port} --multi-thread --disable-encryption
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start the service
    sudo systemctl daemon-reload &> /dev/null
    sudo systemctl enable easymesh.service &> /dev/null
    sudo systemctl start easymesh.service &> /dev/null
    clear

    # Function to set cronjob

    local service_name="easymesh.service"
    local reset_path="/root/easytier/reset.sh"
    
    # Create the reset script
    cat << EOF > "$reset_path"
#! /bin/bash
pids=\$(pgrep easytier)
sudo kill -9 \$pids
sudo systemctl daemon-reload
sudo systemctl restart "$service_name"
EOF

    # Make the script executable
    sudo chmod +x "$reset_path"
    
    # Save existing crontab to a temporary file
    crontab -l > /tmp/crontab.tmp

    # Remove any existing cron jobs for this service
    grep -v "#$service_name" /tmp/crontab.tmp > /tmp/crontab.tmp.new
    mv /tmp/crontab.tmp.new /tmp/crontab.tmp

    # Append the new cron job to the temporary file
    echo -e "${BOLD_GREEN}0 */2 * * * $reset_path #$service_name${NC}" >> /tmp/crontab.tmp

    # Install the modified crontab from the temporary file
    crontab /tmp/crontab.tmp

    # Remove the temporary file
    rm /tmp/crontab.tmp

    echo -e "${BOLD_GREEN}Cron job set up to restart the service '$service_name' every 2 hours.${NC}"

    # Display tunnel configuration details
    echo -e "${BOLD_GREEN}IPv4 Tunnel configuration completed and service started.${NC}"
    echo ""
    echo ""
    echo -e "${BOLD_CYAN}Tunnel Name: ${NC}${Tunnel_Name}"
    echo ""
    echo -e "${BOLD_CYAN}Local IP: ${NC}${Local_IP}"  # Display the valid Local IP entered by the user
    echo ""
    echo -e "${BOLD_CYAN}Destination IP: ${NC}${Destination_IP}"
    echo ""
    echo -e "${BOLD_CYAN}Tunnel Port: ${NC}${Tunnel_Port}"
    echo ""
    echo ""
    read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")" -s
}

#Function to Ask for the new Peer IP address
Add_Destination_Ip() {
    clear
        if [[ ! -f $SERVICE_FILE ]]; then
        not_exist
        sleep 2
        return 1
    fi

    read -p "$(echo -e "${BOLD_GREEN}Enter the new Destination IP Address: ${NC}")" New_Peer_IP
    while ! validate_ip "$New_Peer_IP"; do
        echo "Invalid IP format. Please enter a valid IP address."
        read -p "$(echo -e "${BOLD_GREEN}Enter the new Peer IP Address to add to peers list: ${NC}")" New_Peer_IP
    done
    
    # Extract the current ExecStart line
    current_execstart=$(grep '^ExecStart=' $SERVICE_FILE)

    # Check if the new IP address is already in the ExecStart line
    if [[ $current_execstart == *"$New_Peer_IP"* ]]; then
        echo -e "${BOLD_YELLOW}The IP address $New_Peer_IP is already in the peers list.${NC}"
        read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")" -s
        return 0
    fi

    # Modify the ExecStart line to include the new peer IP address
    new_execstart="${current_execstart/--peers tcp:/--peers tcp://${New_Peer_IP}:2090 tcp:}"

    # Update the service file with the new ExecStart line
    sudo sed -i "s|^ExecStart=.*|$new_execstart|" $SERVICE_FILE

    # Reload systemd and restart the service
    sudo systemctl daemon-reload
    sudo systemctl restart easymesh.service

    echo -e "${BOLD_GREEN}New Peer IP address added and service restarted successfully.${NC}"
    read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")" -s
}

# Function to restart service
restart_service() {
    clear
    log "$(echo -e "${BOLD_GREEN}Restarting Tunnel Service:${NC}")"
    sudo systemctl daemon-reload
    sudo systemctl enable easymesh.service
    sudo systemctl restart easymesh.service
    if [ $? -eq 0 ]; then
        log "$(echo -e "${BOLD_GREEN}Service restarted successfully.${NC}")"
    else
        clear
        log "$(echo -e "${BOLD_RED}Failed to restart service.${NC}")"
        log "$(not_exist)"

    fi
    echo""
    read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")" -s
}

# Function to view service status
view_service_status() {
    clear
    if [[ ! -f $SERVICE_FILE ]]; then
		 not_exist
         echo""
         read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")" -s
    else
        clear
        sudo systemctl status easymesh.service --no-pager
        read -p "$(echo -e "${GREEN}Press Enter to continue...${NC}")" -s

    fi
}

# Function to delete the tunnel service
delete_tunnel() {
    clear
    if [[ ! -f $SERVICE_FILE ]]; then
        not_exist
        sleep 2
        return 1
    fi
    read -p "$(echo -e "${BOLD_RED}Are you sure you want to delete the tunnel service? (y/n): ${NC}")" confirmation
    if [[ $confirmation != "y" ]]; then
        echo -e "${BOLD_YELLOW}Tunnel service deletion canceled.${NC}"
        sleep 2
        return 1
    fi

    if [[ ! -f $SERVICE_FILE ]]; then
        not_exist
        sleep 1
        return 1
    fi

    echo -e "${BOLD_RED}Deleting tunnel service...${NC}"
    echo -e "${BOLD_YELLOW}    Stopping tunnel service...${NC}"
    sudo systemctl stop easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${BOLD_GREEN}    Tunnel service stopped successfully.${NC}"
    else
        echo -e "${BOLD_RED}    Failed to stop EasyMesh service.${NC}"
        sleep 2
        return 1
    fi

    echo -e "${BOLD_YELLOW}    Disabling EasyMesh service...${NC}"
    sudo systemctl disable easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${BOLD_GREEN}    EasyMesh service disabled successfully.${NC}"
    else
        echo -e "${BOLD_RED}    Failed to disable EasyMesh service.${NC}"
        sleep 2
        return 1
    fi

    echo -e "${BOLD_YELLOW}    Removing EasyMesh service...${NC}"
    sudo rm /etc/systemd/system/easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${BOLD_GREEN}    EasyMesh service removed successfully.${NC}"
    else
        echo -e "${BOLD_RED}    Failed to remove EasyMesh service.${NC}"
        sleep 2
        return 1
    fi

    echo -e "${BOLD_YELLOW}    Reloading systemd daemon...${NC}"
    sudo systemctl daemon-reload
    if [[ $? -eq 0 ]]; then
        echo -e "${BOLD_GREEN}    Systemd daemon reloaded successfully.${NC}"
    else
        echo -e "${BOLD_RED}    Failed to reload systemd daemon.${NC}"
        sleep 2
        return 1
    fi

    read -p "    Press Enter to continue..."
}

# Main menu
while true; do
    display_ascii_art
    display_local_ip
    echo -e "1. ${BOLD_GREEN}Create New IPv4Tunnel${NC}"
    echo -e "2. ${CYAN}Add Destination Ip (Ip Maghsad Jdid) ${NC}"
    echo -e "3. ${BOLD_GREEN}Restart Service${NC}"
    echo -e "4. ${BOLD_BLUE}View Service Status${NC}"
    echo -e "5. ${RED}Delete Tunnel${NC}"
    echo -e "0. ${BOLD_PURPLE}Exit${NC}"
    read -p "Enter your choice: " choice

    case $choice in
        1)
            Create_New_IPv4Tunnel
            ;;
        2)
            Add_Destination_Ip
            ;;
        3)
            restart_service
            ;;
        4)
            view_service_status
            ;;
        5)     
            delete_tunnel
            ;;
        0)
            log "Exiting..."
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done