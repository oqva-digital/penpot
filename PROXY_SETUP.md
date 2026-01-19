# Proxy Configuration for Penpot

If you're using a reverse proxy (Caddy/Nginx) for multiple applications, configure Penpot to work through it.

## Cloudflare Tunnel Configuration

Instead of pointing directly to `penpot-frontend:8080`, point to your proxy:

### In Cloudflare Dashboard:

1. Go to: https://one.dash.cloudflare.com/ > Zero Trust > Access > Tunnels
2. Select your tunnel
3. Add/Edit Public Hostname:
   - **Subdomain**: `penpot` (or leave empty for root domain)
   - **Domain**: `mush.so`
   - **Service**: `http://proxy:80` (your existing proxy container)
   - **Path**: (leave empty)

4. For WebSocket support:
   - **Subdomain**: `penpot`
   - **Domain**: `mush.so`
   - **Service**: `http://proxy:80`
   - **Path**: `/ws/*`
   - **Enable WebSocket**: Yes

## Proxy Configuration

### For Caddy (Caddyfile)

Add this to your Caddyfile:

```caddyfile
penpot.mush.so {
    reverse_proxy penpot-frontend:8080 {
        # WebSocket support
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # WebSocket endpoint
    handle /ws/* {
        reverse_proxy penpot-frontend:8080 {
            header_up Connection {>Connection}
            header_up Upgrade {>Upgrade}
        }
    }
}
```

### For Nginx

Add this to your Nginx configuration:

```nginx
server {
    server_name penpot.mush.so;
    
    # Increase body size for file uploads
    client_max_body_size 350M;
    
    # WebSocket support
    location /ws/ {
        proxy_pass http://penpot-frontend:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
    
    # Main application
    location / {
        proxy_pass http://penpot-frontend:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_redirect off;
    }
}
```

## Important Notes

1. **Network**: Make sure your proxy container is on the same Docker network as Penpot (`penpot_penpot` or connect both to a shared network)

2. **Container Name**: The proxy should be able to resolve `penpot-frontend` by name. If they're on different networks, you may need to:
   - Connect the proxy to the `penpot_penpot` network, OR
   - Use the IP address instead of the container name

3. **Check Network Connectivity**:
   ```bash
   # Check if proxy can reach penpot-frontend
   docker exec <proxy-container-name> ping -c 2 penpot-frontend
   
   # Or test HTTP connection
   docker exec <proxy-container-name> wget -O- http://penpot-frontend:8080
   ```

4. **Update docker-compose.production.yml** (if needed):
   If your proxy is in a different docker-compose file, you may need to:
   - Connect the proxy to the `penpot_penpot` network, OR
   - Create a shared external network

## Example: Connecting Proxy to Penpot Network

If your proxy is in a separate docker-compose file:

```yaml
services:
  proxy:
    # ... your proxy config ...
    networks:
      - default
      - penpot_penpot  # Connect to Penpot's network

networks:
  penpot_penpot:
    external: true
    name: penpot_penpot
```

## Testing

After configuration:

1. **Test from proxy container**:
   ```bash
   docker exec <proxy-container-name> curl -I http://penpot-frontend:8080
   ```

2. **Test WebSocket**:
   ```bash
   docker exec <proxy-container-name> curl -i -N \
     -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" \
     -H "Sec-WebSocket-Key: test" \
     http://penpot-frontend:8080/ws/notifications
   ```

3. **Access via Cloudflare Tunnel**:
   - Visit: https://penpot.mush.so
   - Should load the Penpot application

## Troubleshooting

- **502 Bad Gateway**: Proxy can't reach `penpot-frontend` - check network connectivity
- **WebSocket not working**: Ensure WebSocket headers are properly configured
- **Connection timeout**: Verify both containers are running and on the same network
