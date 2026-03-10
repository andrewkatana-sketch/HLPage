#!/bin/bash
# Homepage Service Discovery Script
# Queries remote Docker API and generates services.yaml

# UPDATE THESE TO YOUR ENVIRONMENT
REMOTE_HOST="10.0.0.101"
REMOTE_PORT="2375"
CONFIG_DIR="./config"
SERVICES_FILE="$CONFIG_DIR/services.yaml"
DISCOVERED_SERVICES_FILE="$CONFIG_DIR/discovered.yaml"

echo "Discovering services on $REMOTE_HOST:$REMOTE_PORT..."

# Check if Docker API is accessible
if ! curl -s --connect-timeout 5 "http://$REMOTE_HOST:$REMOTE_PORT/containers/json" > /dev/null 2>&1; then
    echo "Warning: Cannot connect to Docker API at $REMOTE_HOST:$REMOTE_PORT"
    echo "Please enable Docker API or update REMOTE_HOST/REMOTE_PORT in this script"
    exit 0
fi

# Get containers
CONTAINERS=$(curl -s "http://$REMOTE_HOST:$REMOTE_PORT/containers/json" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo "No containers found or API error"
    exit 1
fi

# Generate service entries
echo "# Auto-generated services - DO NOT EDIT MANUALLY" > "$DISCOVERED_SERVICES_FILE"
echo "# Generated: $(date)" >> "$DISCOVERED_SERVICES_FILE"
echo "" >> "$DISCOVERED_SERVICES_FILE"

if command -v jq &> /dev/null; then
    echo "Using jq for JSON parsing..."
    COUNT=$(echo "$CONTAINERS" | jq 'length')
    echo "Found $COUNT containers"

    echo "$CONTAINERS" | jq -r '.[] | .Names[0] // .Name' | while read -r NAME; do
        NAME=$(echo "$NAME" | sed 's/^\///')
        PORTS=$(echo "$CONTAINERS" | jq -r ".[] | select(.Names[0] == \"/$NAME\") | .Ports[] | select(.PublicPort) | \"\(.PublicPort)\"" 2>/dev/null)
        PORT=$(echo "$PORTS" | head -1)

        if [ -n "$PORT" ]; then
            echo "- $NAME:" >> "$DISCOVERED_SERVICES_FILE"
            echo "    href: http://$REMOTE_HOST:$PORT" >> "$DISCOVERED_SERVICES_FILE"
            echo "    icon: $NAME.png" >> "$DISCOVERED_SERVICES_FILE"
            echo "    group: Docker" >> "$DISCOVERED_SERVICES_FILE"
            echo "" >> "$DISCOVERED_SERVICES_FILE"
            echo "Discovered: $NAME on port $PORT"
        fi
    done
fi

echo ""
echo "Discovery complete!"
echo "Discovered services saved to: $DISCOVERED_SERVICES_FILE"
