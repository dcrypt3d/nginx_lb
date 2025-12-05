# Nginx SSL Termination Load Balancer with Sticky Sessions for IIS

This setup configures Nginx as an SSL termination proxy with load balancing and sticky sessions to two IIS hosts.

## Architecture

- **Nginx**: Terminates SSL/TLS connections and load balances traffic at Layer 7 (HTTP)
- **IIS Hosts**: Two backend servers receiving proxied HTTP requests
- **SSL Termination**: SSL/TLS is terminated at Nginx, then forwarded to IIS over HTTP
- **Sticky Sessions**: Uses `ip_hash` to ensure the same client IP always routes to the same backend server
- **Domain**: Configured for `*.host.com` wildcard domain

## Prerequisites

1. Docker and Docker Compose installed
2. SSL certificates (cert.pem and key.pem) placed in the `ssl/` directory
3. Network access to your IIS hosts

## Configuration

### 1. Update IIS Host Addresses

Edit `nginx.conf` in the `upstream iis_backend` block and replace the placeholder hostnames/IPs:
- `iis-host1:443` - Replace with your first IIS server address (port 443 for HTTPS)
- `iis-host2:443` - Replace with your second IIS server address (port 443 for HTTPS)

If your IIS hosts are on different ports or use hostnames, update accordingly.

**Note**: The backend servers are configured to use HTTPS (port 443). Ensure your IIS servers have SSL configured and are listening on port 443.

### 2. SSL Certificates

Place your SSL certificates in the `ssl/` directory:
- `ssl/cert.pem` - Your SSL certificate
- `ssl/key.pem` - Your SSL private key

For testing, you can generate self-signed certificates:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem -out ssl/cert.pem
```

**Important**: Nginx terminates SSL, so it needs valid SSL certificates. IIS receives HTTP traffic (unless configured otherwise).

### 3. Network Configuration

If your IIS hosts are on the same Docker network, ensure they're accessible. If they're external hosts, you may need to:
- Use host.docker.internal (for Docker Desktop on Windows/Mac)
- Use actual IP addresses
- Configure Docker network settings

## Usage

### Start the Nginx container:
```bash
docker-compose up -d
```

### View logs:
```bash
docker-compose logs -f nginx
```

### Stop the container:
```bash
docker-compose down
```

### Reload configuration (without downtime):
```bash
docker-compose exec nginx nginx -s reload
```

## Load Balancing Methods

The current configuration uses `ip_hash` for sticky sessions. You can change this in `nginx.conf` in the `upstream iis_backend` block:

- **`ip_hash`** (current) - Routes based on client IP address (sticky sessions)
  - Same client IP always goes to the same backend server
  - Best for maintaining session state
  - Note: Clients behind NAT/proxies will share the same IP and route to the same server
  
- `least_conn` - Routes to server with fewest active connections
- `round-robin` - Default, distributes requests evenly (no sticky sessions)

### Sticky Sessions

**Sticky sessions are enabled** using `ip_hash`:

- **Method**: IP-based routing ensures session affinity
- **Benefit**: Same client always connects to the same backend server
- **Use Case**: Perfect for applications that maintain session state on the server
- **Consideration**: Multiple users behind the same NAT/proxy will route to the same backend server

**Note**: For cookie-based sticky sessions, you would need a custom Nginx build with the `nginx-module-sticky` module, or use a pre-built image that includes it.

## Health Checks

The configuration includes:
- `max_fails=3` - Mark server as down after 3 failed attempts
- `fail_timeout=30s` - Retry after 30 seconds

A health check endpoint is available at `/nginx-health`.

## Troubleshooting

1. **Check container logs**: `docker-compose logs nginx`
2. **Test configuration**: `docker-compose exec nginx nginx -t`
3. **Verify network connectivity**: Ensure IIS hosts are reachable from the container
4. **Check SSL certificates**: Verify certificates are correctly mounted

## Notes

- **SSL Termination**: SSL/TLS is terminated at Nginx, then forwarded to IIS over HTTPS
- **IIS HTTPS**: IIS receives HTTPS traffic (port 443) - ensure IIS has SSL configured
- **Layer 7 Proxying**: Uses HTTP-level load balancing (can inspect HTTP headers and cookies)
- **Sticky Sessions**: Enabled via `ip_hash` - same client IP routes to same backend
- **Domain Matching**: Configured for `*.host.com` - update the server_name in conf.d/default.conf if needed
- **SSL Certificates**: Nginx requires SSL certificates for termination
- **Backend SSL Verification**: Currently set to `off` - set `proxy_ssl_verify on` in conf.d/default.conf if you want to verify backend certificates
- Adjust timeouts and buffer sizes in the proxy settings based on your application needs

