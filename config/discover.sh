#!/bin/bash
# Homepage Discovery - SUPER FAST using nmap
# Complete scan in under 2 minutes

CONFIG_DIR="/opt/homepage/config"
DISCOVERED_FILE="$CONFIG_DIR/discovered.yaml"
SUBNET="192.168.1.0/24"

echo "========================================"
echo "SUPER FAST Discovery using nmap"
echo "========================================"

echo "Step 1: Quick ping sweep to find live hosts..."

# Get live hosts first (fast)
live_hosts=$(nmap -sn -PR -oG - "$SUBNET" 2>/dev/null | grep "Up" | awk '{print $2}')

if [[ -z "$live_hosts" ]]; then
    echo "No hosts found!"
    exit 1
fi

echo "Found $(echo "$live_hosts" | wc -l) live hosts"

echo "Step 2: Scanning for web services..."

# Scan all live hosts for web ports only, with service detection
nmap -sV --script=http-title -p 80,443,8080,8443,9090,10000,3000,3001,30004,32400,8096,8181,7878,8989,9696,5055,9000,9443 -oG - $live_hosts 2>/dev/null | grep "Ports:" | while read line; do
    host=$(echo "$line" | awk '{print $2}')
    ports=$(echo "$line" | grep -oP '(?<=Ports: )[^ ]+')
    
    echo "Checking $host..."
    
    for port_info in $(echo "$ports" | tr ',' '\n'); do
        port=$(echo "$port_info" | cut -d'/' -f1)
        service=$(echo "$port_info" | cut -d'/' -f5)
        title=$(echo "$port_info" | grep -oP '(?<=http-title: )[^,]+' | head -1)
        
        # Override with port-based detection
        case "$port" in
            3001|30004) svc="AdGuard"; cat="Network"; abbr="AG";;
            9090) svc="Cockpit"; cat="Linux Servers"; abbr="CK";;
            10000) svc="Webmin"; cat="System Admin"; abbr="WM";;
            3000) svc="Homepage"; cat="Homepage"; abbr="HP";;
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
                if [[ "$title" =~ pihole ]]; then svc="Pi-hole"; cat="Network"; abbr="PI"
                elif [[ "$title" =~ adguard ]]; then svc="AdGuard"; cat="Network"; abbr="AG"
                else svc="$title"; cat="Network"; abbr="NET"; fi
                ;;
            443) 
                if [[ "$title" =~ pihole ]]; then svc="Pi-hole"; cat="Network"; abbr="PI"
                elif [[ "$title" =~ adguard ]]; then svc="AdGuard"; cat="Network"; abbr="AG"
                else svc="$title"; cat="Network"; abbr="HTTPS"; fi
                ;;
            *) svc="$title"; cat="System"; abbr="WS";;
        esac
        
        [[ -z "$svc" || "$svc" == " " ]] && svc="Unknown"
        
        # Build URL
        if [[ "$port" == "443" || "$port" == "8443" ]]; then
            url="https://$host"
            [[ "$svc" == "Pi-hole" ]] && url="$url/admin"
        elif [[ "$port" == "80" ]]; then
            url="http://$host"
            [[ "$svc" == "Pi-hole" ]] && url="$url/admin"
        else
            url="http://$host:$port"
        fi
        
        echo "  -> $svc at $url"
        echo "FOUND|$svc|$cat|$abbr|$url"
    done
done | sort -u > /tmp/services.txt

# Parse into array
declare -A DISCOVERED
while IFS='|' read -r a b c d e; do
    key="$b"
    DISCOVERED[$key]="$d|$e|$b|$c"
done < /tmp/services.txt

# Generate YAML
{
    echo "# Auto-generated"
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
echo "Found ${#DISCOVERED[@]} unique services"
echo "Results: $DISCOVERED_FILE"
