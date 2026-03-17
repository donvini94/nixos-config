# VPN-Isolated Media Automation Setup

This document provides step-by-step instructions for configuring the automated media management system with VPN-isolated torrenting.

## Overview

The system consists of:
- **Jellyseerr** - Public request interface at `requests.dumusstbereitsein.de`
- **Sonarr/Radarr** - TV show and movie automation
- **Bazarr** - Subtitle management for TV shows and movies
- **Prowlarr** - Indexer management
- **FlareSolverr** - Cloudflare bypass for protected indexers
- **qBittorrent** - Torrent client (VPN-isolated via Gluetun)
- **Gluetun** - VPN container with kill switch

## Prerequisites

1. NixOS server with Docker enabled
2. Mullvad VPN subscription with WireGuard configuration
3. Access to encrypted secrets management (SOPS)

## Step 1: Get Mullvad WireGuard Credentials

1. Log in to your Mullvad account at https://mullvad.net/
2. Go to "WireGuard configuration"
3. Generate a new key pair or use existing one
4. Download the configuration file or note down:
   - **Private Key** (starts with something like `gK7/U2...`)
   - **Address** (usually something like `10.64.x.x/32`)

## Step 2: Add Mullvad Credentials to Secrets

1. Edit the encrypted secrets file:
   ```bash
   sops secrets/dmbs.yaml
   ```

2. Add the following sections:
   ```yaml
   mullvad:
     private_key: "your-private-key-here"
     addresses: "10.64.x.x/32"
   ```

3. Save and exit the editor

## Step 3: Deploy the Configuration

1. Build and switch to the new configuration:
   ```bash
   sudo nixos-rebuild switch --flake .#alucard
   ```

2. Verify the media-stack service started:
   ```bash
   systemctl status media-stack
   ```

3. Check Docker containers are running:
   ```bash
   docker ps
   ```

You should see containers: gluetun, qbittorrent, sonarr, radarr, bazarr, prowlarr, flaresolverr, jellyseerr

## Step 4: Verify VPN Isolation

**CRITICAL**: Verify that only torrent traffic uses VPN:

1. Check qBittorrent can access internet via VPN:
   ```bash
   # Check qBittorrent's IP (should be Mullvad server IP)
   docker exec qbittorrent curl -s https://ipinfo.io/ip
   ```

2. Check other services use regular internet:
   ```bash
   # These should show your server's real IP
   curl -s https://ipinfo.io/ip
   docker exec sonarr curl -s https://ipinfo.io/ip
   docker exec radarr curl -s https://ipinfo.io/ip
   ```

3. Test VPN kill switch:
   ```bash
   # Stop Gluetun container
   docker stop gluetun
   
   # Verify qBittorrent cannot access internet
   docker exec qbittorrent curl -s --max-time 10 https://ipinfo.io/ip || echo "Good - no internet access"
   
   # Restart Gluetun
   docker start gluetun
   ```

## Step 5: Initial Service Configuration

### Access the Services
- **Jellyseerr**: https://requests.dumusstbereitsein.de (public)
- **Sonarr**: http://localhost:18989 (localhost only)
- **Radarr**: http://localhost:17878 (localhost only)
- **Bazarr**: http://localhost:16767 (localhost only)
- **Prowlarr**: http://localhost:19696 (localhost only)
- **FlareSolverr**: http://localhost:8191 (localhost only)
- **qBittorrent**: http://localhost:18080 (localhost only)

### 5.1 Configure qBittorrent

1. Access qBittorrent at http://localhost:18080
2. Default credentials: `admin` / `adminadmin`
3. Go to Settings → Web UI → Change password
4. Go to Settings → Downloads:
   - Set download path: `/downloads/complete`
   - Set incomplete downloads path: `/downloads/incomplete`
5. Go to Settings → BitTorrent:
   - Set max active torrents to reasonable number (e.g., 5)
   - Enable "Automatically add torrents from" → `/downloads/watch`

### 5.2 Configure FlareSolverr (Cloudflare Bypass)

1. Access FlareSolverr at http://localhost:8191
2. No configuration needed - it runs automatically
3. Note the URL: `http://flaresolverr:8191` (for use in Prowlarr)

### 5.3 Configure Prowlarr (Indexer Management)

1. Access Prowlarr at http://localhost:19696
2. Go to Settings → FlareSolverr → Add FlareSolverr
   - Name: `FlareSolverr`
   - Host: `http://flaresolverr:8191`
   - Test and Save
3. Go to Settings → Indexers → Add Indexer
4. Add your preferred torrent indexers:
   - **1337x**: Select 1337x and configure with FlareSolverr
   - **Other protected sites**: Enable FlareSolverr for any indexer that requires it
5. For each indexer, configure appropriate categories:
   - TV: 5000, 5030, 5040
   - Movies: 2000, 2010, 2020, 2030, 2040, 2050, 2060

### 5.4 Configure Sonarr (TV Shows)

1. Access Sonarr at http://localhost:18989
2. Go to Settings → Media Management:
   - Enable "Rename Episodes"
   - Set TV Folder: `/tv`
3. Go to Settings → Profiles → Quality Profiles:
   - Review and adjust quality preferences
4. Go to Settings → Download Clients → Add Download Client:
   - Type: qBittorrent
   - Host: `gluetun`
   - Port: `18080` (internal container port)
   - Username/Password: From qBittorrent setup
   - Category: `sonarr`
5. Go to Settings → Indexers → Add Indexer:
   - Add indexers configured in Prowlarr

### 5.5 Configure Radarr (Movies)

1. Access Radarr at http://localhost:17878
2. Go to Settings → Media Management:
   - Enable "Rename Movies"
   - Set Movies Folder: `/movies`
3. Go to Settings → Profiles → Quality Profiles:
   - Review and adjust quality preferences
4. Go to Settings → Download Clients → Add Download Client:
   - Type: qBittorrent
   - Host: `gluetun`
   - Port: `18080` (internal container port)
   - Username/Password: From qBittorrent setup
   - Category: `radarr`
5. Go to Settings → Indexers → Add Indexer:
   - Add indexers configured in Prowlarr

### 5.6 Configure Bazarr (Subtitle Management)

1. Access Bazarr at http://localhost:16767
2. Go through the initial setup wizard
3. Go to Settings → Languages:
   - Add your preferred subtitle languages
   - Set language priorities
4. Go to Settings → Providers:
   - Add subtitle providers (OpenSubtitles, Subscene, etc.)
   - Configure API keys if required
5. Go to Settings → Sonarr:
   - Enable Sonarr
   - Host: `http://sonarr:8989`
   - API Key: Get from Sonarr Settings → General
   - Base URL: Leave blank
   - Test connection
6. Go to Settings → Radarr:
   - Enable Radarr
   - Host: `http://radarr:7878`
   - API Key: Get from Radarr Settings → General
   - Base URL: Leave blank
   - Test connection
7. Go to Settings → Scheduler:
   - Configure automatic subtitle search intervals
   - Set upgrade existing subtitles preferences

### 5.7 Configure Jellyseerr (Request Interface)

1. Access Jellyseerr at https://requests.dumusstbereitsein.de
2. Follow initial setup wizard
3. Configure Jellyfin integration:
   - Jellyfin URL: `https://stream.dumusstbereitsein.de`
   - API Key: Get from Jellyfin admin panel
4. Configure Sonarr:
   - URL: `http://sonarr:8989` (internal container URL)
   - API Key: Get from Sonarr settings
   - Root Folder: `/tv`
5. Configure Radarr:
   - URL: `http://radarr:7878` (internal container URL)
   - API Key: Get from Radarr settings
   - Root Folder: `/movies`

## Step 6: Test the Complete Flow

1. **Request Content**: Go to https://requests.dumusstbereitsein.de and request a TV show or movie
2. **Monitor Processing**: 
   - Check Jellyseerr for request status
   - Check Sonarr/Radarr for search and download
   - Check qBittorrent for active downloads
3. **Verify File Organization**: 
   - Downloads should appear in `/mnt/hetzner/downloads`
   - Completed files should move to `/mnt/hetzner/shows` or `/mnt/hetzner/movies`
4. **Confirm Jellyfin Integration**: New content should appear in Jellyfin library

## Troubleshooting

### VPN Issues
- Check Gluetun logs: `docker logs gluetun`
- Verify Mullvad credentials in secrets
- Test connectivity: `docker exec qbittorrent curl ipinfo.io`

### Download Issues
- Check qBittorrent is accessible from Sonarr/Radarr
- Verify indexers are working in Prowlarr
- Check download client settings in Sonarr/Radarr

### File Permission Issues
- Ensure all containers run as jellyfin user (PUID/PGID 982)
- Check directory ownership: `ls -la /mnt/hetzner/`

### Service Connectivity
- All admin interfaces are localhost-only for security
- Use SSH tunneling for remote admin access:
  ```bash
  ssh -L 18989:localhost:18989 -L 17878:localhost:17878 -L 16767:localhost:16767 -L 19696:localhost:19696 -L 8191:localhost:8191 -L 18080:localhost:18080 user@alucard
  ```

## Security Notes

- Only Jellyseerr is publicly accessible
- All other admin interfaces are localhost-only
- qBittorrent traffic is completely isolated behind VPN
- VPN kill switch prevents any leaks if connection drops
- All containers run with minimal privileges

## Maintenance

### Update Containers
```bash
cd /var/lib/media-stack
docker-compose pull
systemctl restart media-stack
```

### View Logs
```bash
docker logs gluetun
docker logs qbittorrent
docker logs sonarr
docker logs radarr
docker logs bazarr
```

### Backup Configuration
Container configurations are stored in Docker volumes. Consider backing up:
- Sonarr database and config
- Radarr database and config
- Bazarr database and config
- Prowlarr database and config
- Jellyseerr database and config
