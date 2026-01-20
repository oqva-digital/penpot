# Installation Guide - Penpot Self-Hosted

This guide describes how to install and configure a self-hosted Penpot instance using the provided automated scripts.

## Prerequisites

### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+, Debian 11+, etc.), macOS 10.15+, or Windows with Docker Desktop
- **Architecture**: x86_64 (amd64) or ARM64 (aarch64)
- **RAM**: Minimum 4GB (recommended 8GB+)
- **Disk**: Minimum 20GB free space
- **Network**: Internet connection for downloading images and updates

### Required Software

1. **Docker** (version 20.10+)
   - Linux: [Install Docker](https://docs.docker.com/engine/install/)
   - macOS: [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - Windows: [Docker Desktop](https://www.docker.com/products/docker-desktop)

2. **Docker Compose** (version 2.0+)
   - Usually included with Docker Desktop
   - Linux: Installed with Docker or via `apt install docker-compose-plugin`

3. **Python 3** (version 3.7+)
   - Required for generating secret keys
   - Linux: `apt install python3` or `yum install python3`
   - macOS: Already included or via Homebrew: `brew install python3`
   - Windows: Included with Docker Desktop or install separately

4. **Git**
   - Required to clone the repository and sync with upstream

### Cloudflare Account (Optional but Recommended)

- Cloudflare account with Zero Trust enabled
- Cloudflare Tunnel token (obtained from dashboard)

## Quick Installation

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR-ORG/penpot.git
cd penpot
```

### 2. Run Setup Script

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

The script will:
- Automatically detect the operating system
- Check prerequisites
- Automatically generate keys and passwords
- Build Docker images (may take several minutes)
- Configure and start all services

### 3. Configure Cloudflare Tunnel (Optional)

If you have a Cloudflare Tunnel token:

1. Edit `.env.local` and add:
   ```
   CLOUDFLARE_TUNNEL_TOKEN=your-token-here
   ```

2. Configure the hostname in Cloudflare dashboard:
   - Visit: https://one.dash.cloudflare.com/
   - Go to: Zero Trust > Access > Tunnels
   - Select your tunnel
   - Add a Public Hostname:
     - **Hostname**: `penpot.yourdomain.com`
     - **Service**: `http://penpot-frontend:8080`
     - **Path**: (leave empty)

3. For WebSocket (real-time collaboration):
   - Add another Public Hostname:
     - **Hostname**: `penpot.yourdomain.com`
     - **Service**: `http://penpot-frontend:8080`
     - **Path**: `/ws/*`
     - **Enable WebSocket**: Yes

4. Restart the service:
   ```bash
   docker compose -f docker-compose.production.yml restart cloudflared
   ```

## Detailed Installation

### Manual Step-by-Step

If you prefer to do the setup manually or understand each step:

#### 1. Prepare Environment

```bash
# Check Docker
docker --version
docker compose version

# Check Python
python3 --version
```

#### 2. Generate Configurations

```bash
# Copy template
cp env.example .env.local

# Generate keys and passwords
./scripts/generate-secrets.sh .env.local

# Edit necessary configurations
nano .env.local
```

#### 3. Build Docker Images

```bash
# Build images (may take 10-30 minutes)
./scripts/build-images.sh
```

Or skip the build and use pre-built images:

```bash
./scripts/setup.sh --skip-build
```

#### 4. Start Services

```bash
docker compose -f docker-compose.production.yml --env-file .env.local up -d
```

#### 5. Check Status

```bash
# Check container status
docker compose -f docker-compose.production.yml ps

# View logs
docker compose -f docker-compose.production.yml logs -f
```

## Post-Installation Configuration

### 1. Create Administrator Account

1. Access the application at: `https://penpot.yourdomain.com` (or `http://localhost:9001` if not using Cloudflare)
2. Click "Sign up" or "Register"
3. Create your first account (will be automatically admin)

### 2. Configure SMTP (Recommended for Production)

Edit `.env.local` and configure a real SMTP provider:

```bash
# Example with Gmail
PENPOT_SMTP_HOST=smtp.gmail.com
PENPOT_SMTP_PORT=587
PENPOT_SMTP_USERNAME=your-email@gmail.com
PENPOT_SMTP_PASSWORD=your-app-password
PENPOT_SMTP_TLS=true
PENPOT_SMTP_SSL=false
```

Then restart the backend:

```bash
docker compose -f docker-compose.production.yml restart penpot-backend
```

### 3. Configure Security Flags

For production, edit `.env.local` and remove insecure flags:

```bash
# Remove these flags:
# disable-email-verification
# disable-secure-session-cookies

# Use secure flags:
PENPOT_FLAGS=enable-login-with-password enable-smtp enable-registration secure-session-cookies email-verification
```

## Useful Commands

### Service Management

```bash
# Start services
docker compose -f docker-compose.production.yml up -d

# Stop services
docker compose -f docker-compose.production.yml down

# Restart services
docker compose -f docker-compose.production.yml restart

# View logs
docker compose -f docker-compose.production.yml logs -f

# View logs for a specific service
docker compose -f docker-compose.production.yml logs -f penpot-backend

# View status
docker compose -f docker-compose.production.yml ps
```

### Backup and Restore

```bash
# Database backup
docker compose -f docker-compose.production.yml exec penpot-postgres pg_dump -U penpot penpot > backup-$(date +%Y%m%d).sql

# Assets backup
docker run --rm -v penpot_assets:/data -v $(pwd):/backup ubuntu tar czf /backup/assets-$(date +%Y%m%d).tar.gz /data

# Database restore
cat backup-20240101.sql | docker compose -f docker-compose.production.yml exec -T penpot-postgres psql -U penpot penpot
```

### Updates

```bash
# Sync with upstream
./scripts/update-from-upstream.sh

# Rebuild images
./scripts/build-images.sh

# Update services
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d
```

## Troubleshooting

### Services Don't Start

```bash
# Check logs
docker compose -f docker-compose.production.yml logs

# Check if ports are in use
netstat -tulpn | grep -E '9001|6060|6061|5432|6379'

# Check system resources
docker stats
```

### Database Connection Error

```bash
# Check if PostgreSQL is running
docker compose -f docker-compose.production.yml exec penpot-postgres pg_isready -U penpot

# Check PostgreSQL logs
docker compose -f docker-compose.production.yml logs penpot-postgres
```

### Cloudflare Tunnel Not Connecting

1. Verify the token is correct in `.env.local`
2. Check logs: `docker compose -f docker-compose.production.yml logs cloudflared`
3. Verify the hostname is configured in Cloudflare dashboard
4. Test connectivity: `curl https://penpot.yourdomain.com`

### Permission Issues

```bash
# Adjust volume permissions
docker compose -f docker-compose.production.yml down
sudo chown -R 1001:1001 /var/lib/docker/volumes/penpot_assets/_data
docker compose -f docker-compose.production.yml up -d
```

### Complete Rebuild

If something goes wrong and you want to start from scratch:

```bash
# Stop and remove everything
docker compose -f docker-compose.production.yml down -v

# Remove images
docker rmi penpotapp/frontend penpotapp/backend penpotapp/exporter

# Run setup again
./scripts/setup.sh
```

## Installation Validation

After installation, verify:

- [ ] All containers are running: `docker compose ps`
- [ ] Backend responds: `curl http://localhost:6060/api/health`
- [ ] Frontend accessible: Open `http://localhost:9001` in browser
- [ ] Cloudflare Tunnel connected (if configured): Check dashboard
- [ ] Can create account and login
- [ ] Emails are sent (check mailcatch at `http://localhost:1080`)

## Next Steps

- Read the [Customization Guide](CUSTOMIZATION.md) to personalize Penpot
- Consult the [Updates Guide](UPDATES.md) to stay synchronized with upstream
- See the [Endpoints Documentation](ENDPOINTS.md) for integrations

## Support

- [Official Penpot Documentation](https://help.penpot.app/)
- [Penpot Community](https://community.penpot.app/)
- [Repository Issues](https://github.com/penpot/penpot/issues)
