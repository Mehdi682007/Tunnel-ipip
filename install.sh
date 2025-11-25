#!/bin/bash

# ==============================
#  IPv6 Tunnel Manager 😎
#  Single-tunnel + Add Ports
# ==============================

SERVICE_NAME="tunnel-setup.service"
SCRIPT_PATH="/usr/local/bin/tunnel-setup.sh"
CONFIG_DIR="/etc/tunnel-manager"
CONFIG_FILE="${CONFIG_DIR}/config"

# Colors & styles
BOLD="\e[1m"
RESET="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
BLUE="\e[34m"
GRAY="\e[90m"

CHECK="✅"
CROSS="❌"
WARN="⚠️"
INFO="ℹ️"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${CROSS} This script must be run as root (use sudo).${RESET}"
    exit 1
  fi
}

pause() {
  echo
  read -rp "Press Enter to return to the menu..." _
}

detect_local_ip() {
  local ip
  ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){ if($i=="src"){print $(i+1); exit}}}')
  echo "$ip"
}

print_banner() {
  clear
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)

  if (( cols >= 120 )); then
    # ترمینال بزرگ → لوگوی ASCII
    echo -e "${MAGENTA}"
    cat << 'EOF'
 _______                                _______   __            __    __                __  __        ______  _______  ______  _______  
|       \                              |       \ |  \          |  \  |  \              |  \|  \      |      \|       \|      \|       \ 
| $$$$$$$\ ______    ______    _______ | $$$$$$$\ \$$  ______   \$$ _| $$_     ______  | $$| $$       \$$$$$$| $$$$$$$\\$$$$$$| $$$$$$$\
| $$__/ $$|      \  /      \  /       \| $$  | $$|  \ /      \ |  \|   $$ \   |      \ | $$| $$        | $$  | $$__/ $$ | $$  | $$__/ $$
| $$    $$ \$$$$$$\|  $$$$$$\|  $$$$$$$| $$  | $$| $$|  $$$$$$\| $$ \$$$$$$    \$$$$$$\| $$| $$        | $$  | $$    $$ | $$  | $$    $$
| $$$$$$$ /      $$| $$   \$$ \$$    \ | $$  | $$| $$| $$  | $$| $$  | $$ __  /      $$| $$| $$        | $$  | $$$$$$$  | $$  | $$$$$$$ 
| $$     |  $$$$$$$| $$       _\$$$$$$\| $$__/ $$| $$| $$__| $$| $$  | $$|  \|  $$$$$$$| $$| $$       _| $$_ | $$      _| $$_ | $$      
| $$      \$$    $$| $$      |       $$| $$    $$| $$ \$$    $$| $$   \$$  $$ \$$    $$| $$| $$      |   $$ \| $$     |   $$ \| $$      
 \$$       \$$$$$$$ \$$       \$$$$$$$  \$$$$$$$  \$$ _\$$$$$$$ \$$    \$$$$   \$$$$$$$ \$$ \$$       \$$$$$$ \$$      \$$$$$$ \$$      
                                                     |  \__| $$                                                                         
                                                      \$$    $$                                                                         
                                                       \$$$$$$                                                                          

EOF
    echo -e "${RESET}"
  fi

  # هدر ساده (بدون وسط‌چین و بدون \e خام)
  echo -e "${BOLD}${CYAN}Tunnel Manager v1.0${RESET}"
  echo -e "${GRAY}YouTube: youtube.com/@PARSDIGITAL   GitHub: github.com/Mehdi682007${RESET}"
  echo
}

install_or_update_tunnel() {
  require_root
  mkdir -p "$CONFIG_DIR"

  print_banner
  echo -e "${BOLD}🌐 IPv6 / IP-in-IPv6 Tunnel Installer${RESET}"
  echo "----------------------------------------"
  echo
  echo "Which server is this?"
  echo "  1) 🌍🌐✅ Kharej server"
  echo "  2) 🟢⚪️🔴 Iran server"
  read -rp "Choose your role [1-2]: " ROLE_CHOICE

  case "$ROLE_CHOICE" in
    1)
      ROLE="foreign"
      echo -e "${CHECK} Role set to: Foreign (Kharej) server"
      ;;
    2)
      ROLE="iran"
      echo -e "${CHECK} Role set to: Iran server"
      ;;
    *)
      echo -e "${RED}${CROSS} Invalid choice.${RESET}"
      return
      ;;
  esac

  # Store role for later (for Add Ports)
  echo "ROLE=${ROLE}" > "$CONFIG_FILE"

  echo
  echo -e "${INFO} Detecting local public IPv4..."
  LOCAL_IP=$(detect_local_ip)

  if [[ -z "$LOCAL_IP" ]]; then
    echo -e "${WARN} Could not auto-detect local IP."
    read -rp "Please enter this server's public IPv4: " LOCAL_IP
  else
    echo -e "${CHECK} Auto-detected local IP: ${CYAN}$LOCAL_IP${RESET}"
    read -rp "Press Enter if this is correct, or type another IPv4: " LOCAL_IP_OVERRIDE
    if [[ -n "$LOCAL_IP_OVERRIDE" ]]; then
      LOCAL_IP="$LOCAL_IP_OVERRIDE"
    fi
  fi

  if [[ -z "$LOCAL_IP" ]]; then
    echo -e "${RED}${CROSS} Local IP cannot be empty.${RESET}"
    return
  fi

  echo
  read -rp "Enter the public IPv4 of the opposite server: " REMOTE_IP
  if [[ -z "$REMOTE_IP" ]]; then
    echo -e "${RED}${CROSS} Remote IP cannot be empty.${RESET}"
    return
  fi

  # Role-based tunnel addressing (single tunnel)
  if [[ "$ROLE" == "foreign" ]]; then
    FC_LOCAL="fc00::1"
    FC_REMOTE="fc00::2"
    PTP_IPV4_LOCAL="192.168.13.1/30"
    PTP_REMOTE_IPV4="192.168.13.2"
  else
    FC_LOCAL="fc00::2"
    FC_REMOTE="fc00::1"
    PTP_IPV4_LOCAL="192.168.13.2/30"
    PTP_REMOTE_IPV4="192.168.13.1"
  fi

  PORT_LIST=""
  if [[ "$ROLE" == "iran" ]]; then
    echo
    echo -e "${INFO} Port forwarding on Iran server:"
    echo "  - UDP port 53 will be forwarded to ${PTP_REMOTE_IPV4} by default."
    echo "  - You can optionally forward extra TCP ports through the tunnel."
    echo
    echo "Example format: 443,8080,2096"
    read -rp "Enter TCP ports to forward (empty for none): " PORT_LIST
  fi

  echo
  echo -e "${INFO} Creating tunnel script at ${YELLOW}${SCRIPT_PATH}${RESET} ..."

  # Generate /usr/local/bin/tunnel-setup.sh
  cat > "$SCRIPT_PATH" <<EOF
#!/bin/bash
set -e

# Auto-generated by tunnel-manager.sh

# Clean any existing tunnels
ip tunnel del 6to4_PD_TUN 2>/dev/null || true
ip -6 tunnel del ip6PD_tun 2>/dev/null || true

# 1) 6to4 tunnel using public IPv4
ip tunnel add 6to4_PD_TUN mode sit remote ${REMOTE_IP} local ${LOCAL_IP}
ip -6 addr add ${FC_LOCAL}/64 dev 6to4_PD_TUN
ip link set 6to4_PD_TUN mtu 1480
ip link set 6to4_PD_TUN up

# 2) IPv6-in-IPv6 tunnel carrying IPv4 /30
ip -6 tunnel add ip6PD_tun mode ipip6 remote ${FC_REMOTE} local ${FC_LOCAL}
ip addr add ${PTP_IPV4_LOCAL} dev ip6PD_tun
ip link set ip6PD_tun mtu 1440
ip link set ip6PD_tun up
EOF

  # Extra config for Iran server
  if [[ "$ROLE" == "iran" ]]; then
    cat >> "$SCRIPT_PATH" <<'EOF'

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true

REMOTE_IPV4_TUN="192.168.13.1"

# Forward DNS (UDP/53) to remote via tunnel (with comment for cleanup)
if ! iptables -t nat -C PREROUTING -p udp --dport 53 -j DNAT --to-destination ${REMOTE_IPV4_TUN} -m comment --comment "tunnel-setup" 2>/dev/null; then
  iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination ${REMOTE_IPV4_TUN} -m comment --comment "tunnel-setup"
fi
EOF

    if [[ -n "$PORT_LIST" ]]; then
      CLEAN_PORTS=$(echo "$PORT_LIST" | tr -d '[:space:]')
      IFS=',' read -r -a PORT_ARRAY <<< "$CLEAN_PORTS"

      cat >> "$SCRIPT_PATH" <<'EOF'

# Forward custom TCP ports defined by user
REMOTE_IPV4_TUN="192.168.13.1"
EOF

      for PORT in "${PORT_ARRAY[@]}"; do
        if [[ "$PORT" =~ ^[0-9]+$ ]]; then
          cat >> "$SCRIPT_PATH" <<EOF
if ! iptables -t nat -C PREROUTING -p tcp --dport ${PORT} -j DNAT --to-destination \${REMOTE_IPV4_TUN} -m comment --comment "tunnel-setup" 2>/dev/null; then
  iptables -t nat -A PREROUTING -p tcp --dport ${PORT} -j DNAT --to-destination \${REMOTE_IPV4_TUN} -m comment --comment "tunnel-setup"
fi
EOF
        fi
      done
    fi

    cat >> "$SCRIPT_PATH" <<'EOF'

# NAT for outgoing traffic (with comment for cleanup)
if ! iptables -t nat -C POSTROUTING -j MASQUERADE -m comment --comment "tunnel-setup" 2>/dev/null; then
  iptables -t nat -A POSTROUTING -j MASQUERADE -m comment --comment "tunnel-setup"
fi
EOF
  fi

  cat >> "$SCRIPT_PATH" <<'EOF'

exit 0
EOF

  chmod +x "$SCRIPT_PATH"
  echo -e "${CHECK} Tunnel setup script created and made executable."

  echo
  echo -e "${INFO} Creating systemd service at ${YELLOW}/etc/systemd/system/${SERVICE_NAME}${RESET} ..."

  cat > "/etc/systemd/system/${SERVICE_NAME}" <<EOF
[Unit]
Description=Setup Network Tunnel (IPv6 sit + ipip6)
After=network.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH}
RemainAfterExit=yes
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  echo -e "${CHECK} Systemd service file created."

  echo
  echo -e "${INFO} Reloading systemd, enabling and starting the service..."
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
  systemctl start "$SERVICE_NAME" || true

  echo
  echo -e "${CHECK} Installation / update completed."
  echo
  systemctl --no-pager status "$SERVICE_NAME" || true

  echo
  read -rp "Do you want to reboot the server now? [y/N]: " REBOOT_ANSWER
  case "$REBOOT_ANSWER" in
    y|Y|yes|YES)
      echo -e "${YELLOW}🔁 Rebooting server...${RESET}"
      reboot
      ;;
    *)
      echo -e "${INFO} No reboot requested. Tunnel will be restored on next boot.${RESET}"
      ;;
  esac
}

status_tunnel() {
  require_root
  print_banner
  echo -e "${BOLD}🧪 Tunnel Status${RESET}"
  echo "------------------"
  echo

  if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
    state=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "unknown")
    enabled=$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "disabled")

    if [[ "$state" == "active" ]]; then
      echo -e "Service: ${GREEN}ACTIVE${RESET} (${enabled}) ${CHECK}"
    else
      echo -e "Service: ${RED}${state^^}${RESET} (${enabled}) ${CROSS}"
    fi
  else
    echo -e "${RED}${CROSS} Service ${SERVICE_NAME} is not installed.${RESET}"
  fi

  echo
  echo -e "${CYAN}ip tunnel show 6to4_PD_TUN:${RESET}"
  ip tunnel show 6to4_PD_TUN 2>/dev/null || echo "  (not found)"

  echo
  echo -e "${CYAN}ip -6 tunnel show ip6PD_tun:${RESET}"
  ip -6 tunnel show ip6PD_tun 2>/dev/null || echo "  (not found)"

  echo
  echo -e "${CYAN}NAT rules with comment \"tunnel-setup\":${RESET}"
  if command -v iptables-save >/dev/null 2>&1; then
    iptables-save | grep "tunnel-setup" || echo "  (no matching rules)"
  else
    echo "  iptables-save not available."
  fi

  pause
}

add_ports_menu() {
  require_root
  print_banner
  echo -e "${BOLD}➕ Add TCP Ports (Iran server only)${RESET}"
  echo "-------------------------------------"
  echo

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}${CROSS} No config file found. Please run Install/Update first.${RESET}"
    pause
    return
  fi

  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  if [[ "$ROLE" != "iran" ]]; then
    echo -e "${RED}${CROSS} This option is only valid on the Iran server.${RESET}"
    pause
    return
  fi

  if ! command -v iptables-save >/dev/null 2>&1; then
    echo -e "${RED}${CROSS} iptables-save is not available on this system.${RESET}"
    pause
    return
  fi

  REMOTE_IPV4_TUN="192.168.13.1"

  echo -e "${INFO} Existing tunnel remote IPv4 (inside /30): ${CYAN}${REMOTE_IPV4_TUN}${RESET}"
  echo
  echo "Enter additional TCP ports to forward through this tunnel."
  echo "Example: 443,8080,2096"
  read -rp "TCP ports: " NEW_PORTS

  if [[ -z "$NEW_PORTS" ]]; then
    echo -e "${WARN} No ports entered. Nothing to do.${RESET}"
    pause
    return
  fi

  CLEAN_PORTS=$(echo "$NEW_PORTS" | tr -d '[:space:]')
  IFS=',' read -r -a PORT_ARRAY <<< "$CLEAN_PORTS"

  echo
  for PORT in "${PORT_ARRAY[@]}"; do
    if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}${CROSS} Skipping invalid port: ${PORT}${RESET}"
      continue
    fi

    # Check if this port is already used in any tunnel-setup rule
    if iptables-save | grep -q "tunnel-setup" | grep -q -- "--dport ${PORT}"; then
      echo -e "${RED}${CROSS} Port ${PORT} is already used in an existing tunnel rule. Skipping.${RESET}"
      continue
    fi

    echo -e "${INFO} Adding DNAT rule for TCP port ${PORT} -> ${REMOTE_IPV4_TUN}"
    iptables -t nat -A PREROUTING -p tcp --dport "${PORT}" -j DNAT --to-destination "${REMOTE_IPV4_TUN}" -m comment --comment "tunnel-setup" 2>/dev/null \
      && echo -e "${GREEN}${CHECK} Port ${PORT} added.${RESET}" \
      || echo -e "${RED}${CROSS} Failed to add rule for port ${PORT}.${RESET}"
  done

  echo
  echo -e "${CHECK} Done processing requested ports.${RESET}"
  pause
}

uninstall_tunnel() {
  require_root
  print_banner
  echo -e "${BOLD}🧹 Uninstall Tunnel${RESET}"
  echo "----------------------"
  echo
  read -rp "Are you sure you want to remove the tunnel and service? [y/N]: " CONFIRM
  case "$CONFIRM" in
    y|Y|yes|YES)
      ;;
    *)
      echo -e "${INFO} Uninstall cancelled.${RESET}"
      pause
      return
      ;;
  esac

  echo
  echo -e "${INFO} Stopping and disabling service (if exists)..."
  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}"
  systemctl daemon-reload
  echo -e "${CHECK} Service removed."

  echo
  echo -e "${INFO} Deleting tunnels (if exist)..."
  ip tunnel del 6to4_PD_TUN 2>/dev/null || true
  ip -6 tunnel del ip6PD_tun 2>/dev/null || true
  echo -e "${CHECK} Tunnel devices cleaned."

  echo
  echo -e "${INFO} Removing iptables rules with comment \"tunnel-setup\" (if any)..."
  if command -v iptables-save >/dev/null 2>&1; then
    iptables-save | awk '
      /^#/ {next}
      /^\*/ {table = substr($1,2); next}
      /^COMMIT/ {next}
      /tunnel-setup/ {
        gsub("^-A ","-D ");
        print table " " $0
      }
    ' | while read -r table rule; do
      iptables -t "$table" $rule 2>/dev/null || true
    done
    echo -e "${CHECK} iptables rules cleaned (where tagged)."
  else
    echo -e "${WARN} iptables-save not available, cannot auto-clean rules.${RESET}"
  fi

  echo
  echo -e "${INFO} Removing script file ${YELLOW}${SCRIPT_PATH}${RESET} ..."
  rm -f "$SCRIPT_PATH" 2>/dev/null || true
  rm -f "$CONFIG_FILE" 2>/dev/null || true

  echo
  echo -e "${GREEN}${CHECK} Tunnel fully uninstalled.${RESET}"
  pause
}

print_menu_box() {
  # کادر ساده، چپ بسته / راست باز → هیچ داستانی با طول رشته نداریم
  echo -e "${MAGENTA}┌──────────────────────────────────────────────${RESET}"
  echo -e "${MAGENTA}│${RESET} IPv6 Tunnel Manager (sit + ipip6)"
  echo -e "${MAGENTA}├──────────────────────────────────────────────${RESET}"
  echo -e "${MAGENTA}│${RESET} 1) Install / Update tunnel"
  echo -e "${MAGENTA}│${RESET} 2) Show tunnel status"
  echo -e "${MAGENTA}│${RESET} 3) Add TCP ports (Iran only)"
  echo -e "${MAGENTA}│${RESET} 4) Uninstall tunnel"
  echo -e "${MAGENTA}│${RESET} 5) Exit"
  echo -e "${MAGENTA}└──────────────────────────────────────────────${RESET}"
  echo
}

main_menu() {
  while true; do
    print_banner
    print_menu_box
    read -rp "Your choice [1-5]: " CHOICE

    case "$CHOICE" in
      1) install_or_update_tunnel ;;
      2) status_tunnel ;;
      3) add_ports_menu ;;
      4) uninstall_tunnel ;;
      5)
        echo
        echo -e "${CHECK} Goodbye! 👋"
        exit 0
        ;;
      *)
        echo -e "${RED}${CROSS} Invalid choice. Please use 1-5.${RESET}"
        sleep 1.5
        ;;
    esac
  done
}

main_menu
