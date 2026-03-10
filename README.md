# Homepage Deployment Package

## Quick Start

### 1. Copy to Ubuntu Host (192.168.1.19)

```bash
# On Ubuntu host, create directory:
sudo mkdir -p /opt/homepage
sudo chown $USER:$USER /opt/homepage

# Copy this entire folder to /opt/homepage/
```

### 2. Enable TrueNAS Docker API

On TrueNAS (192.168.1.111), create a docker-socket-proxy container:

```bash
# SSH to TrueNAS and run:
docker run -d \
  --name docker-socket-proxy \
  -p 2375:2375 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  tecnativa/docker-socket-proxy \
  CONTAINERS=1 INFO=1
```

### 3. Start Homepage

```bash
cd /opt/homepage
docker compose up -d
```

### 4. Access Homepage

```
http://192.168.1.19:3000
```

---

## Configuration Files

### settings.yaml
- Theme, timezone, weather, layout
- Edit to customize appearance

### services.yaml
- Service widgets (Pi-hole is pre-configured)
- Add more services here
- Discovered services will be imported from discovered.yaml

### bookmarks.yaml
- Quick links to Cockpit, TrueNAS, Pi-hole, etc.
- Edit to add/remove bookmarks

---

## Running Discovery Script

```bash
# Manual run:
cd /opt/homepage
./discover-services.sh

# Auto-run daily (add to crontab):
crontab -e
# Add: 0 6 * * * /opt/homepage/discover-services.sh >> /var/log/homepage-discovery.log 2>&1
```

---

## Adding More Services

### Option 1: Docker Labels (Recommended for local containers)

Add to your docker-compose.yml:
```yaml
services:
  your-service:
    image: your-image
    labels:
      homepage.group: Media
      homepage.name: Your Service
      homepage.icon: service.png
      homepage.url: http://service:port
```

Homepage will auto-discover containers with these labels.

### Option 2: Manual services.yaml

```yaml
- Service Name:
    href: http://192.168.1.111:8080
    icon: service.png
    description: Your service
    widget:
      type: service-type
      url: http://192.168.1.111:8080
```

---

## Troubleshooting

### Can't connect to TrueNAS
- Verify Docker API is enabled on TrueNAS
- Check firewall allows port 2375 between hosts

### Services not showing
- Check Homepage logs: `docker logs homepage`
- Verify services.yaml syntax: https://gethomepage.dev/configs/services/

### Widgets not working
- Check API keys/credentials in config
- Verify service is accessible from Homepage container

---

## Files Included

```
homepage/
├── config/
│   ├── settings.yaml      # General settings
│   ├── services.yaml     # Service widgets
│   ├── bookmarks.yaml    # Quick links
│   └── discovered.yaml  # Auto-generated (after running script)
├── docker-compose.yml    # Homepage container
├── discover-services.sh  # Discovery script
└── README.md           # This file
```
