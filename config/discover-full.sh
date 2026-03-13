#!/bin/bash
# Homepage Discovery - FULL SCAN using nmap's service detection
# Uses nmap -sV to detect ALL services automatically

CONFIG_DIR="/opt/homepage/config"
DISCOVERED_FILE="$CONFIG_DIR/discovered.yaml"
SUBNET="192.168.1"

echo "========================================"
echo "Full Network Discovery"
echo "========================================"

# Get live hosts
echo "Finding live hosts..."
live_hosts=$(nmap -sn -PR "$SUBNET.0/24" -oG - 2>/dev/null | grep "Up" | awk '{print $2}')
count=$(echo "$live_hosts" | wc -l)
echo "Found $count hosts"

# Full port scan with service detection
echo "Scanning for all services (this may take a few minutes)..."
nmap -sV -p- -T4 -oG - $live_hosts 2>/dev/null | grep "Ports:" > /tmp/nmap_scan.txt

echo "Analyzing results..."

declare -A DISCOVERED

while read line; do
    host=$(echo "$line" | awk '{print $2}')
    ports=$(echo "$line" | grep -oP '(?<=Ports: )[^ ]+')
    
    for port_info in $(echo "$ports" | tr ',' '\n'); do
        port=$(echo "$port_info" | cut -d'/' -f1)
        state=$(echo "$port_info" | cut -d'/' -f2)
        service=$(echo "$port_info" | cut -d'/' -f5)
        
        [[ "$state" != "open" ]] && continue
        
        # Determine URL
        if [[ "$port" == "443" ]]; then url="https://$host"
        elif [[ "$port" == "80" ]]; then url="http://$host"
        else url="http://$host:$port"; fi
        
        # Identify by nmap service name or port
        case "$port" in
            3001|30004|30080) svc="AdGuard"; cat="Network"; abbr="AG";;
            30121) svc="Nx Witness"; cat="Network"; abbr="NX";;
            30094) svc="MeTube"; cat="Media"; abbr="MT";;
            9090) svc="Cockpit"; cat="Linux Servers"; abbr="CK";;
            10000) svc="Webmin"; cat="System Admin"; abbr="WM";;
            32400) svc="Plex"; cat="Media"; abbr="PX";;
            8096) svc="Jellyfin"; cat="Media"; abbr="JF";;
            8181) svc="Tautulli"; cat="Media"; abbr="TA";;
            7878) svc="Radarr"; cat="Media"; abbr="RA";;
            8989) svc="Sonarr"; cat="Media"; abbr="SN";;
            9696) svc="Overseerr"; cat="Media"; abbr="OV";;
            5055) svc="qbittorrent"; cat="Media"; abbr="QB";;
            9000) svc="Portainer"; cat="Container"; abbr="PA";;
            9443) svc="TrueNAS"; cat="Storage"; abbr="TN";;
            80)
                [[ "$service" =~ pihole ]] && svc="Pi-hole" cat="Network" abbr="PI" && url="$url/admin"
                [[ "$service" =~ nginx ]] && svc="Web Server" cat="Network" abbr="WEB"
                [[ -z "$svc" ]] && svc="HTTP" cat="Network" abbr="HTTP"
                ;;
            *) 
                svc="$service"; cat="System"; abbr="SY"
                ;;
        esac
        
        [[ -z "$svc" ]] && continue
        
        key="$cat:$svc"
        if [[ -z "${DISCOVERED[$key]}" ]]; then
            DISCOVERED[$key]="$abbr|$url|$svc|$cat"
            echo "  -> $svc at $url"
        fi
    done
done < /tmp/nmap_scan.txt

# Generate YAML
{
    echo "# Auto-generated - Full scan"
    echo "# Generated: $(date)"
    echo ""
    for category in "Network" "Linux Servers" "System Admin" "Media" "Container" "Storage" "Homepage" "System"; do
        found=false
        for key in "${!DISCOVERED[@]}"; do
            IFS='|' read -r abbr url svc cat <<< "${DISCOVERED[$key]}"
            if [[ "$cat" == "$category" ]]; then
                if ! $found; then echo "- $category:"; found=true; fi
                echo "    - $svc:"
                echo "        - abbr: $abbr"
                echo "          href: $url"
            fi
        done
    done
} > "$DISCOVERED_FILE"

echo ""
echo "========================================"
echo "Found ${#DISCOVERED[@]} services"
echo "Results: $DISCOVERED_FILE"
