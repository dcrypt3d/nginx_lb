# Local Nginx Installation Guide (CentOS/RHEL)

This guide will help you install and configure Nginx locally on CentOS/RHEL without Docker.

## Prerequisites

- CentOS Stream 9/10, RHEL 9/10, or compatible Linux distribution
- Root or sudo privileges
- Network access to your IIS backend servers
- SELinux configured appropriately (or disabled for testing)

## Step 1: Install Nginx

### Option A: Install from EPEL Repository (Recommended)

1. Enable EPEL repository:
   ```bash
   # For CentOS Stream 9/RHEL 9
   sudo dnf install epel-release -y
   
   # For CentOS Stream 8/RHEL 8
   sudo dnf install epel-release -y
   ```

2. Install Nginx:
   ```bash
   sudo dnf install nginx -y
   ```

3. Verify installation:
   ```bash
   nginx -v
   ```

### Option B: Install from Nginx Official Repository

1. Install prerequisites:
   ```bash
   sudo dnf install -y curl gnupg2 ca-certificates
   ```

2. Add Nginx repository:
   ```bash
   # For CentOS Stream 9/RHEL 9
   sudo tee /etc/yum.repos.d/nginx.repo <<EOF
   [nginx-stable]
   name=nginx stable repo
   baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
   gpgcheck=1
   enabled=1
   gpgkey=https://nginx.org/keys/nginx_signing.key
   EOF
   ```

3. Install Nginx:
   ```bash
   sudo dnf install nginx -y
   ```

## Step 2: Create Required Directories

```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Create conf.d directory (usually exists, but ensure it does)
sudo mkdir -p /etc/nginx/conf.d

# Ensure log directory exists
sudo mkdir -p /var/log/nginx

# Set proper permissions
sudo chmod 755 /etc/nginx/ssl
sudo chmod 644 /etc/nginx/ssl/*.pem 2>/dev/null || true
```

## Step 3: Copy Configuration Files

1. **Backup existing configuration**:
   ```bash
   sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
   sudo cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.backup 2>/dev/null || true
   ```

2. **Copy new configuration files**:
   ```bash
   # Copy main configuration
   sudo cp nginx.conf /etc/nginx/nginx.conf
   
   # Copy server configuration
   sudo cp conf.d/default.conf /etc/nginx/conf.d/default.conf
   ```

3. **Set proper permissions**:
   ```bash
   sudo chmod 644 /etc/nginx/nginx.conf
   sudo chmod 644 /etc/nginx/conf.d/default.conf
   ```

## Step 4: Copy SSL Certificates

```bash
# Copy SSL certificates
sudo cp ssl/cert.pem /etc/nginx/ssl/cert.pem
sudo cp ssl/key.pem /etc/nginx/ssl/key.pem

# Set secure permissions (key must be readable only by root)
sudo chmod 644 /etc/nginx/ssl/cert.pem
sudo chmod 600 /etc/nginx/ssl/key.pem
sudo chown root:root /etc/nginx/ssl/*.pem
```

## Step 5: Update IIS Backend Server Addresses

Edit `/etc/nginx/nginx.conf` and update the upstream servers:

```bash
sudo vi /etc/nginx/nginx.conf
```

Find the `upstream iis_backend` section and update:

```nginx
upstream iis_backend {
    ip_hash;
    server your-iis-server1.com:443 max_fails=3 fail_timeout=30s;
    server your-iis-server2.com:443 max_fails=3 fail_timeout=30s;
}
```

Or use IP addresses:

```nginx
upstream iis_backend {
    ip_hash;
    server 192.168.1.10:443 max_fails=3 fail_timeout=30s;
    server 192.168.1.11:443 max_fails=3 fail_timeout=30s;
}
```

## Step 6: Update Domain Name (if needed)

Edit `/etc/nginx/conf.d/default.conf`:

```bash
sudo vi /etc/nginx/conf.d/default.conf
```

Update the `server_name` directive:

```nginx
server_name *.host.com;  # Change to your actual domain
```

## Step 7: Configure SELinux (if enabled)

If SELinux is enabled, you may need to allow nginx to bind to ports and access files:

```bash
# Allow nginx to bind to ports 80 and 443
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_relay 1

# Allow nginx to read SSL certificates
sudo semanage fcontext -a -t httpd_exec_t "/etc/nginx/ssl(/.*)?" 2>/dev/null || true
sudo restorecon -R /etc/nginx/ssl

# If you need to connect to backend servers
sudo setsebool -P httpd_can_network_connect 1
```

## Step 8: Configure Firewall

Allow HTTP and HTTPS traffic:

```bash
# For firewalld (default on CentOS/RHEL)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

## Step 9: Test Configuration

```bash
# Test nginx configuration
sudo nginx -t
```

Expected output:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

If there are errors, fix them before proceeding.

## Step 10: Start and Enable Nginx

```bash
# Start nginx service
sudo systemctl start nginx

# Enable nginx to start on boot
sudo systemctl enable nginx

# Check status
sudo systemctl status nginx
```

## Step 11: Verify Installation

1. **Check if nginx is running**:
   ```bash
   sudo systemctl status nginx
   ```

2. **Check if ports are listening**:
   ```bash
   sudo ss -tlnp | grep -E ':80|:443'
   # or
   sudo netstat -tlnp | grep -E ':80|:443'
   ```

3. **Test HTTP redirect**:
   ```bash
   curl -I http://your-domain.host.com
   # Should return 301 redirect to HTTPS
   ```

4. **Test HTTPS**:
   ```bash
   curl -I https://your-domain.host.com
   # Should return 200 OK
   ```

5. **Check logs**:
   ```bash
   sudo tail -f /var/log/nginx/access.log
   sudo tail -f /var/log/nginx/error.log
   ```

## Common Commands

### Start Nginx
```bash
sudo systemctl start nginx
```

### Stop Nginx
```bash
sudo systemctl stop nginx
```

### Restart Nginx
```bash
sudo systemctl restart nginx
```

### Reload Configuration (without downtime)
```bash
sudo systemctl reload nginx
# or
sudo nginx -s reload
```

### Test Configuration
```bash
sudo nginx -t
```

### View Status
```bash
sudo systemctl status nginx
```

### View Logs
```bash
# Access log
sudo tail -f /var/log/nginx/access.log

# Error log
sudo tail -f /var/log/nginx/error.log

# Both logs
sudo tail -f /var/log/nginx/*.log
```

## Troubleshooting

### Port Already in Use

If ports 80 or 443 are already in use:

```bash
# Find what's using the port
sudo ss -tlnp | grep :80
sudo ss -tlnp | grep :443

# Stop Apache if it's running (if you want nginx to handle these ports)
sudo systemctl stop httpd
sudo systemctl disable httpd
```

### Permission Denied

- Ensure nginx user has read access to SSL certificates
- Check SELinux context: `ls -Z /etc/nginx/ssl/`
- Verify file permissions: `ls -l /etc/nginx/ssl/`

### Configuration Errors

- Test configuration: `sudo nginx -t`
- Check error log: `sudo tail -50 /var/log/nginx/error.log`
- Verify all paths are correct

### SSL Certificate Errors

- Verify certificate files exist: `ls -l /etc/nginx/ssl/`
- Check file permissions: `ls -l /etc/nginx/ssl/*.pem`
- Verify certificate paths in config are correct
- Test certificate: `openssl x509 -in /etc/nginx/ssl/cert.pem -text -noout`

### Backend Connection Errors

- Verify IIS servers are accessible: `ping your-iis-server.com`
- Test HTTPS connection: `curl -k https://your-iis-server.com:443`
- Check firewall rules allow outbound connections
- Verify DNS resolution: `nslookup your-iis-server.com`

### SELinux Issues

If SELinux is blocking nginx:

```bash
# Check SELinux status
getenforce

# View SELinux denials
sudo ausearch -m avc -ts recent

# Temporarily set to permissive (for testing)
sudo setenforce 0

# Permanently disable (not recommended for production)
sudo vi /etc/selinux/config
# Set SELINUX=disabled
```

### Service Won't Start

```bash
# Check service status
sudo systemctl status nginx

# Check journal logs
sudo journalctl -u nginx -n 50

# Check error log
sudo tail -50 /var/log/nginx/error.log
```

## Log Rotation

Nginx logs can grow large. Set up log rotation:

```bash
# Edit logrotate config
sudo vi /etc/logrotate.d/nginx
```

Add or verify:

```
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 0640 nginx adm
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}
```

## Security Hardening

1. **Keep Nginx updated**:
   ```bash
   sudo dnf update nginx -y
   ```

2. **Review firewall rules**:
   ```bash
   sudo firewall-cmd --list-all
   ```

3. **Monitor logs regularly**:
   ```bash
   sudo tail -f /var/log/nginx/access.log
   ```

4. **Review NIST compliance**: See `NIST_COMPLIANCE.md`

## Uninstallation

If you need to remove nginx:

```bash
# Stop and disable service
sudo systemctl stop nginx
sudo systemctl disable nginx

# Remove nginx package
sudo dnf remove nginx -y

# Remove configuration files (optional)
sudo rm -rf /etc/nginx

# Remove log files (optional)
sudo rm -rf /var/log/nginx
```

## Next Steps

- Review `NIST_COMPLIANCE.md` for security compliance details
- Update SSL certificates before expiration
- Set up monitoring and alerting
- Configure log aggregation if needed
- Review and adjust rate limiting based on traffic patterns

## Additional Resources

- Nginx Documentation: https://nginx.org/en/docs/
- CentOS Documentation: https://www.centos.org/docs/
- RHEL Documentation: https://access.redhat.com/documentation/

