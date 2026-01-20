# Endpoints Documentation - Penpot Self-Hosted

This documentation lists all endpoints, URLs, and APIs available in the self-hosted Penpot instance.

## Public URLs

### Main Access

- **Public URL**: `https://penpot.yourdomain.com` (configured via Cloudflare Tunnel)
- **Local URL**: `http://localhost:9001` (if not using Cloudflare)

### Web Interface

- **Application**: `https://penpot.yourdomain.com/`
- **Login**: `https://penpot.yourdomain.com/#/auth/login`
- **Register**: `https://penpot.yourdomain.com/#/auth/register`
- **Dashboard**: `https://penpot.yourdomain.com/#/dashboard`

## Internal Endpoints (Docker Network)

### Frontend

- **Service**: `penpot-frontend`
- **Internal URL**: `http://penpot-frontend:8080`
- **External Port**: `9001` (only if not using Cloudflare)
- **Health Check**: `http://penpot-frontend:8080/`

### Backend API

- **Service**: `penpot-backend`
- **Internal URL**: `http://penpot-backend:6060`
- **Health Check**: `http://penpot-backend:6060/api/health`
- **RPC Endpoint**: `http://penpot-backend:6060/api/rpc`

### Exporter

- **Service**: `penpot-exporter`
- **Internal URL**: `http://penpot-exporter:6061`
- **Health Check**: `http://penpot-exporter:6061/health`

### PostgreSQL

- **Service**: `penpot-postgres`
- **Internal Host**: `penpot-postgres`
- **Port**: `5432`
- **Database**: `penpot`
- **User**: `penpot`
- **Connection String**: `postgresql://penpot:password@penpot-postgres:5432/penpot`

### Valkey (Redis-compatible)

- **Service**: `penpot-valkey`
- **Internal Host**: `penpot-valkey`
- **Port**: `6379`
- **Database**: `0`
- **Connection String**: `redis://penpot-valkey:6379/0`

### Mailcatch (Development)

- **Service**: `penpot-mailcatch`
- **SMTP**: `penpot-mailcatch:1025`
- **Web Interface**: `http://localhost:1080` (exposed port)

## REST APIs

### RPC Endpoint

Penpot uses an RPC (Remote Procedure Call) system instead of traditional REST.

**Base URL**: `https://penpot.yourdomain.com/api/rpc`

#### Authentication

```bash
# Get authentication token
curl -X POST https://penpot.yourdomain.com/api/rpc/command/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password"
  }'

# Response includes session token (cookie)
```

#### RPC Call Examples

```bash
# List projects (requires authentication)
curl -X POST https://penpot.yourdomain.com/api/rpc/command/projects/get-projects \
  -H "Content-Type: application/json" \
  -H "Cookie: auth-token=your-token" \
  -d '{}'

# Get profile information
curl -X POST https://penpot.yourdomain.com/api/rpc/command/profile/get-profile \
  -H "Content-Type: application/json" \
  -H "Cookie: auth-token=your-token" \
  -d '{}'
```

### Health Check Endpoints

#### Backend Health

```bash
curl http://penpot-backend:6060/api/health
# Response: {"status": "ok"}
```

#### Exporter Health

```bash
curl http://penpot-exporter:6061/health
# Response: {"status": "ok"}
```

#### Frontend Health

```bash
curl http://penpot-frontend:8080/
# Response: Application HTML
```

## WebSockets

### Real-Time Notifications

- **URL**: `wss://penpot.yourdomain.com/ws/notifications`
- **Internal**: `ws://penpot-backend:6060/ws/notifications`

Used for:
- Real-time collaboration
- Change notifications
- State synchronization

### Connection Example

```javascript
const ws = new WebSocket('wss://penpot.yourdomain.com/ws/notifications');

ws.onopen = () => {
  console.log('Connected to WebSocket');
  // Send authentication message
  ws.send(JSON.stringify({
    type: 'auth',
    token: 'your-token'
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Notification received:', data);
};
```

## Export Endpoints

### Export Design as PNG

```
POST /api/export
Content-Type: application/json

{
  "file-id": "file-uuid",
  "object-id": "object-uuid",
  "format": "png",
  "scale": 1
}
```

### Export Design as SVG

```
POST /api/export
Content-Type: application/json

{
  "file-id": "file-uuid",
  "object-id": "object-uuid",
  "format": "svg"
}
```

### Export Design as PDF

```
POST /api/export
Content-Type: application/json

{
  "file-id": "file-uuid",
  "object-id": "object-uuid",
  "format": "pdf"
}
```

## Asset Endpoints

### Upload Asset

```
POST /api/assets/upload
Content-Type: multipart/form-data

file: [file]
```

### Download Asset

```
GET /api/assets/{asset-id}
```

### List Assets

```
GET /api/assets?team-id={team-id}
```

## Authentication Endpoints

### Login

```
POST /api/rpc/command/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}
```

### Logout

```
POST /api/rpc/command/auth/logout
Cookie: auth-token=your-token
```

### Register

```
POST /api/rpc/command/auth/register
Content-Type: application/json

{
  "email": "new@example.com",
  "password": "password",
  "fullname": "Full Name"
}
```

### Password Recovery

```
POST /api/rpc/command/auth/recovery-request
Content-Type: application/json

{
  "email": "user@example.com"
}
```

## Project Endpoints

### List Projects

```
POST /api/rpc/command/projects/get-projects
Content-Type: application/json
Cookie: auth-token=your-token

{
  "team-id": "team-uuid"
}
```

### Create Project

```
POST /api/rpc/command/projects/create-project
Content-Type: application/json
Cookie: auth-token=your-token

{
  "team-id": "team-uuid",
  "name": "Project Name"
}
```

### Get Project

```
POST /api/rpc/command/projects/get-project
Content-Type: application/json
Cookie: auth-token=your-token

{
  "id": "project-uuid"
}
```

## File Endpoints

### Get File

```
POST /api/rpc/command/files/get-file
Content-Type: application/json
Cookie: auth-token=your-token

{
  "id": "file-uuid"
}
```

### Create File

```
POST /api/rpc/command/files/create-file
Content-Type: application/json
Cookie: auth-token=your-token

{
  "project-id": "project-uuid",
  "name": "File Name"
}
```

### Update File

```
POST /api/rpc/command/files/update-file
Content-Type: application/json
Cookie: auth-token=your-token

{
  "id": "file-uuid",
  "data": { ... }
}
```

## Team Endpoints

### List Teams

```
POST /api/rpc/command/teams/get-teams
Content-Type: application/json
Cookie: auth-token=your-token

{}
```

### Create Team

```
POST /api/rpc/command/teams/create-team
Content-Type: application/json
Cookie: auth-token=your-token

{
  "name": "Team Name"
}
```

## Exposed Ports

### Host Ports (if not using Cloudflare)

| Service | Internal Port | External Port | Description |
|---------|---------------|---------------|-------------|
| Frontend | 8080 | 9001 | Web interface |
| Mailcatch | 1080 | 1080 | Email interface |

### Internal Ports (Docker Network)

| Service | Port | Description |
|---------|------|-------------|
| Backend | 6060 | RPC API |
| Exporter | 6061 | Export service |
| PostgreSQL | 5432 | Database |
| Valkey | 6379 | Cache/WebSocket |

## Cloudflare Tunnel Configuration

### Configured Hostnames

In Cloudflare dashboard, configure:

1. **Main Hostname**:
   - Hostname: `penpot.yourdomain.com`
   - Service: `http://penpot-frontend:8080`
   - Path: (empty)

2. **WebSocket**:
   - Hostname: `penpot.yourdomain.com`
   - Service: `http://penpot-frontend:8080`
   - Path: `/ws/*`
   - Enable WebSocket: Yes

## Usage Examples

### cURL

```bash
# Health check
curl https://penpot.yourdomain.com/api/health

# Login
curl -X POST https://penpot.yourdomain.com/api/rpc/command/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}' \
  -c cookies.txt

# List projects (using session cookie)
curl -X POST https://penpot.yourdomain.com/api/rpc/command/projects/get-projects \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"team-id":"team-uuid"}'
```

### JavaScript/TypeScript

```typescript
// Basic RPC client
class PenpotClient {
  constructor(private baseUrl: string, private token: string) {}

  async rpc(command: string, params: any) {
    const response = await fetch(`${this.baseUrl}/api/rpc/command/${command}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': `auth-token=${this.token}`
      },
      body: JSON.stringify(params)
    });
    return response.json();
  }

  async getProjects(teamId: string) {
    return this.rpc('projects/get-projects', { 'team-id': teamId });
  }
}
```

### Python

```python
import requests

class PenpotClient:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.cookies.set('auth-token', token)
    
    def rpc(self, command, params):
        response = self.session.post(
            f'{self.base_url}/api/rpc/command/{command}',
            json=params
        )
        return response.json()
    
    def get_projects(self, team_id):
        return self.rpc('projects/get-projects', {'team-id': team_id})
```

## Security

### Authentication

- Session tokens via HTTP-only cookies
- OAuth support (GitHub, Google, etc.) if configured
- LDAP/OIDC support if configured

### HTTPS

- Required in production via Cloudflare Tunnel
- Certificates managed by Cloudflare

### Rate Limiting

- Configured in Cloudflare (if using)
- Can be configured in backend if needed

## Monitoring

### Available Metrics

- Health checks for all services
- Logs via `docker compose logs`
- Cloudflare metrics (if using)

### Logs

```bash
# All services
docker compose -f docker-compose.production.yml logs -f

# Specific service
docker compose -f docker-compose.production.yml logs -f penpot-backend
```

## References

- [Penpot API Documentation](https://help.penpot.app/technical-guide/)
- [Integration Guide](https://help.penpot.app/technical-guide/integrations/)
- [Webhooks](https://help.penpot.app/technical-guide/webhooks/)
