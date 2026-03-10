#!/bin/bash
# Homepage Service Discovery Script
# Queries TrueNAS Docker API and generates services.yaml

TRUENAS_HOST="192.168.1.111"
TRUENAS_PORT="2375"
CONFIG_DIR="./config"
SERVICES_FILE="$CONFIG_DIR/services.yaml"
DISCOVERED_SERVICES_FILE="$CONFIG_DIR/discovered.yaml"

echo "Discovering services on TrueNAS ($TRUENAS_HOST:$TRUENAS_PORT)..."

# Check if TrueNAS Docker API is accessible
if ! curl -s --connect-timeout 5 "http://$TRUENAS_HOST:$TRUENAS_PORT/containers/json" > /dev/null 2>&1; then
    echo "Warning: Cannot connect to TrueNAS Docker API at $TRUENAS_HOST:$TRUENAS_PORT"
    echo "Please enable Docker API on TrueNAS or update TRUENAS_HOST/TRUENAS_PORT in this script"
    exit 0
fi

# Get containers from TrueNAS
CONTAINERS=$(curl -s "http://$TRUENAS_HOST:$TRUENAS_PORT/containers/json" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo "No containers found or API error"
    exit 1
fi

# Parse containers and generate service entries
echo "# Auto-generated services - DO NOT EDIT MANUALLY" > "$DISCOVERED_SERVICES_FILE"
echo "# Generated: $(date)" >> "$DISCOVERED_SERVICES_FILE"
echo "" >> "$DISCOVERED_SERVICES_FILE"

# Check if jq is available for JSON parsing
if command -v jq &> /dev/null; then
    echo "Using jq for JSON parsing..."
    
    # Get container count
    COUNT=$(echo "$CONTAINERS" | jq 'length')
    echo "Found $COUNT containers"
    
    # Parse each container
    echo "$CONTAINERS" | jq -r '.[] | .Names[0] // .Name' | while read -r NAME; do
        # Clean up container name (remove leading /)
        NAME=$(echo "$NAME" | sed 's/^\///')
        
        # Get ports
        PORTS=$(echo "$CONTAINERS" | jq -r ".[] | select(.Names[0] == \"/$NAME\") | .Ports[] | select(.PublicPort) | \"\(.PublicPort)\"" 2>/dev/null)
        
        # Get labels
        LABELS=$(echo "$CONTAINERS" | jq -r ".[] | select(.Names[0] == \"/$NAME\") | .Labels" 2>/dev/null)
        
        # Try to get homepage group from labels
        GROUP=$(echo "$LABELS" | jq -r '."homepage.group"' 2>/dev/null)
        if [ "$GROUP" == "null" ] || [ -z "$GROUP" ]; then
            GROUP="Docker"
        fi
        
        # Get first public port
        PORT=$(echo "$PORTS" | head -1)
        
        if [ -n "$PORT" ]; then
            echo "- $NAME:" >> "$DISCOVERED_SERVICES_FILE"
            echo "    href: http://$TRUENAS_HOST:$PORT" >> "$DISCOVERED_SERVICES_FILE"
            echo "    icon: $NAME.png" >> "$DISCOVERED_SERVICES_FILE"
            echo "    group: $GROUP" >> "$DISCOVERED_SERVICES_FILE"
            echo "    description: Container on TrueNAS" >> "$DISCOVERED_SERVICES_FILE"
            echo "    widget:" >> "$DISCOVERED_SERVICES_FILE"
            echo "      type: custom" >> "$DISCOVERED_SERVICES_FILE"
            echo "      url: http://$TRUENAS_HOST:$PORT" >> "$DISCOVERED_SERVICES_FILE"
            echo "" >> "$DISCOVERED_SERVICES_FILE"
            echo "Discovered: $NAME on port $PORT"
        fi
    done
else
    echo "jq not found - using basic parsing..."
    # Basic parsing without jq
    echo "# Install jq for better parsing: sudo apt install jq" >> "$DISCOVERED_SERVICES_FILE"
    
    # Extract container names and ports using basic grep/sed
    echo "$CONTAINERS" | grep -o '"Names":\[[^]]*\]' | sed 's/"Names":\[//g' | sed 's/\]//g' | tr ',' '\n' | while read -r NAME; do
        NAME=$(echo "$NAME" | sed 's/"//g' | sed 's/^\///')
        if [ -n "$NAME" ]; then
            echo "- $NAME:" >> "$DISCOVERED_SERVICES_FILE"
            echo "    href: http://$TRUENAS_HOST" >> "$DISCOVERED_SERVICES_FILE"
            echo "    group: Docker" >> "$DISCOVERED_SERVICES_FILE"
            echo "" >> "$DISCOVERED_SERVICES_FILE"
            echo "Discovered: $NAME"
        fi
    done
fi

echo ""
echo "Discovery complete!"
echo "Discovered services saved to: $DISCOVERED_SERVICES_FILE"
echo ""
echo "To use discovered services, add this line to services.yaml:"
echo "  - import: discovered.yaml"
