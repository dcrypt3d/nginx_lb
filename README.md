# Nginx SSL Termination Load Balancer with Sticky Sessions for IIS

This setup configures Nginx as an SSL termination proxy with load balancing and sticky sessions to two IIS hosts.

## Architecture

- **Nginx**: Terminates SSL/TLS connections and load balances traffic at Layer 7 (HTTP)
- **IIS Hosts**: Two backend servers receiving proxied HTTPS requests
- **SSL Termination**: SSL/TLS is terminated at Nginx, then re-encrypted and forwarded to IIS over HTTPS
- **Sticky Sessions**: Uses `ip_hash` to ensure the same client IP always routes to the same backend server
- **Domain**: Configured for `*.host.com` wildcard domain

## Installation Options

This project supports two installation methods:

1. **Docker** (Container-based) - See [Docker Installation](#docker-installation)
2. **Local CentOS/RHEL Install** - See [Local CentOS/RHEL Installation](#local-centosrhel-installation)

---

## Docker Installation

### Prerequisites

1. Docker and Docker Compose installed
2. SSL certificates (cert.pem and key.pem) placed in the `ssl/` directory
3. Network access to your IIS hosts

### Configuration

#### 1. Update IIS Host Addresses

Edit `nginx.conf` in the `upstream iis_backend` block and replace the placeholder hostnames/IPs:
- `iis-host1:443` - Replace with your first IIS server address (port 443 for HTTPS)
- `iis-host2:443` - Replace with your second IIS server address (port 443 for HTTPS)

If your IIS hosts are on different ports or use hostnames, update accordingly.

**Note**: The backend servers are configured to use HTTPS (port 443). Ensure your IIS servers have SSL configured and are listening on port 443.

#### 2. SSL Certificates

Place your SSL certificates in the `ssl/` directory:
- `ssl/cert.pem` - Your SSL certificate
- `ssl/key.pem` - Your SSL private key

For testing, you can generate self-signed certificates:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem -out ssl/cert.pem
```

**Important**: Nginx terminates SSL, so it needs valid SSL certificates. Backend connections to IIS use HTTPS.

#### 3. Network Configuration

If your IIS hosts are on the same Docker network, ensure they're accessible. If they're external hosts, you may need to:
- Use actual IP addresses
- Configure Docker network settings

### Usage

#### Start the Nginx container:
```bash
docker-compose up -d
```

#### View logs:
```bash
docker-compose logs -f nginx
```

#### Stop the container:
```bash
docker-compose down
```

#### Reload configuration (without downtime):
```bash
docker-compose exec nginx nginx -s reload
```

---

## Local CentOS/RHEL Installation

### Prerequisites

1. CentOS Stream 9/10, RHEL 9/10, or compatible Linux distribution
2. Root or sudo privileges
3. SSL certificates (cert.pem and key.pem)
4. Network access to your IIS hosts

### Quick Setup

1. **Install Nginx**:
   ```bash
   sudo dnf install epel-release -y
   sudo dnf install nginx -y
   ```

2. **Run Setup Script** (as root or sudo):
   ```bash
   sudo chmod +x setup-centos.sh
   sudo ./setup-centos.sh
   ```

3. **Manual Setup** (if preferred): See [INSTALL_CENTOS.md](INSTALL_CENTOS.md) for detailed instructions

### Configuration

#### 1. Update IIS Host Addresses

Edit `/etc/nginx/nginx.conf` in the `upstream iis_backend` block and replace the placeholder hostnames/IPs.

#### 2. SSL Certificates

Copy your SSL certificates to `/etc/nginx/ssl/`:
- `cert.pem` - Your SSL certificate
- `key.pem` - Your SSL private key

Set proper permissions:
```bash
sudo chmod 644 /etc/nginx/ssl/cert.pem
sudo chmod 600 /etc/nginx/ssl/key.pem
```

#### 3. Update Domain Name

Edit `/etc/nginx/conf.d/default.conf` and update `server_name *.host.com` to your actual domain.

#### 4. Configure Firewall

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### Usage

#### Test configuration:
```bash
sudo nginx -t
```

#### Start and enable Nginx:
```bash
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Reload configuration (without downtime):
```bash
sudo systemctl reload nginx
```

#### Check status:
```bash
sudo systemctl status nginx
```

#### View logs:
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

For detailed installation instructions, see [INSTALL_CENTOS.md](INSTALL_CENTOS.md).

---

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

### Docker Installation
1. **Check container logs**: `docker-compose logs nginx`
2. **Test configuration**: `docker-compose exec nginx nginx -t`
3. **Verify network connectivity**: Ensure IIS hosts are reachable from the container
4. **Check SSL certificates**: Verify certificates are correctly mounted

### Local CentOS/RHEL Installation
1. **Check logs**: `sudo tail -50 /var/log/nginx/error.log`
2. **Test configuration**: `sudo nginx -t`
3. **Verify network connectivity**: `ping your-iis-server.com`
4. **Check SSL certificates**: Verify certificates exist: `ls -l /etc/nginx/ssl/`
5. **Check ports**: Ensure ports are listening: `sudo ss -tlnp | grep -E ':80|:443'`
6. **Check SELinux**: `getenforce` and review denials if needed
7. **Check firewall**: `sudo firewall-cmd --list-all`

## Notes

- **SSL Termination**: SSL/TLS is terminated at Nginx, then re-encrypted and forwarded to IIS over HTTPS
- **IIS HTTPS**: IIS receives HTTPS traffic (port 443) - ensure IIS has SSL configured
- **Layer 7 Proxying**: Uses HTTP-level load balancing (can inspect HTTP headers and cookies)
- **Sticky Sessions**: Enabled via `ip_hash` - same client IP routes to same backend
- **Domain Matching**: Configured for `*.host.com` - update the server_name in conf.d/default.conf if needed
- **SSL Certificates**: Nginx requires SSL certificates for termination
- **Backend SSL Verification**: Set to `on` for security - verifies backend certificates (NIST compliant)
- **NIST Compliance**: Configuration aligns with NIST SP 800-52 Rev. 2 - see [NIST_COMPLIANCE.md](NIST_COMPLIANCE.md)
- Adjust timeouts and buffer sizes in the proxy settings based on your application needs

## Files

- `nginx.conf` - Main nginx configuration (Docker/Linux/CentOS paths)
- `conf.d/default.conf` - Server configuration (Docker/Linux/CentOS paths)
- `docker-compose.yml` - Docker Compose configuration
- `setup-centos.sh` - CentOS/RHEL setup script
- `INSTALL_CENTOS.md` - Detailed CentOS/RHEL installation guide
- `NIST_COMPLIANCE.md` - NIST compliance documentation

