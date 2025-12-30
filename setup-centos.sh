#!/bin/bash
# Nginx CentOS/RHEL Setup Script
# Run this script as root or with sudo

set -e  # Exit on error

echo "========================================"
echo "Nginx Load Balancer - CentOS/RHEL Setup"
echo "========================================"
echo ""

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root or with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

NGINX_CONF="/etc/nginx/nginx.conf"
NGINX_CONFD="/etc/nginx/conf.d"
NGINX_SSL="/etc/nginx/ssl"
NGINX_LOGS="/var/log/nginx"

echo "Step 1: Checking if Nginx is installed..."
if ! command -v nginx &> /dev/null; then
    echo ""
    echo "Nginx is not installed. Installing..."
    
    # Detect OS version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "ERROR: Cannot detect OS version"
        exit 1
    fi
    
    # Install EPEL if not present
    if ! rpm -q epel-release &> /dev/null; then
        echo "Installing EPEL repository..."
        dnf install -y epel-release
    fi
    
    # Install nginx
    echo "Installing Nginx..."
    dnf install -y nginx
    
    echo "[OK] Nginx installed"
else
    echo "[OK] Nginx is already installed"
    nginx -v
fi
echo ""

echo "Step 2: Creating required directories..."
mkdir -p "$NGINX_SSL"
mkdir -p "$NGINX_CONFD"
mkdir -p "$NGINX_LOGS"
echo "[OK] Directories created"
echo ""

echo "Step 3: Backing up existing configuration..."
if [ -f "$NGINX_CONF" ]; then
    cp "$NGINX_CONF" "${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[OK] Backed up existing nginx.conf"
fi

if [ -f "$NGINX_CONFD/default.conf" ]; then
    cp "$NGINX_CONFD/default.conf" "${NGINX_CONFD}/default.conf.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[OK] Backed up existing default.conf"
fi
echo ""

echo "Step 4: Copying configuration files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/nginx.conf" ]; then
    cp "$SCRIPT_DIR/nginx.conf" "$NGINX_CONF"
    chmod 644 "$NGINX_CONF"
    echo "[OK] Copied nginx.conf to $NGINX_CONF"
else
    echo "[WARNING] nginx.conf not found in $SCRIPT_DIR"
fi

if [ -f "$SCRIPT_DIR/conf.d/default.conf" ]; then
    cp "$SCRIPT_DIR/conf.d/default.conf" "$NGINX_CONFD/default.conf"
    chmod 644 "$NGINX_CONFD/default.conf"
    echo "[OK] Copied default.conf to $NGINX_CONFD/default.conf"
else
    echo "[WARNING] conf.d/default.conf not found in $SCRIPT_DIR"
fi
echo ""

echo "Step 5: Copying SSL certificates..."
if [ -f "$SCRIPT_DIR/ssl/cert.pem" ]; then
    cp "$SCRIPT_DIR/ssl/cert.pem" "$NGINX_SSL/cert.pem"
    chmod 644 "$NGINX_SSL/cert.pem"
    chown root:root "$NGINX_SSL/cert.pem"
    echo "[OK] Copied SSL certificate"
else
    echo "[WARNING] SSL certificate (ssl/cert.pem) not found!"
    echo "You will need to copy your SSL certificates to $NGINX_SSL"
fi

if [ -f "$SCRIPT_DIR/ssl/key.pem" ]; then
    cp "$SCRIPT_DIR/ssl/key.pem" "$NGINX_SSL/key.pem"
    chmod 600 "$NGINX_SSL/key.pem"
    chown root:root "$NGINX_SSL/key.pem"
    echo "[OK] Copied SSL private key"
else
    echo "[WARNING] SSL private key (ssl/key.pem) not found!"
    echo "You will need to copy your SSL certificates to $NGINX_SSL"
fi
echo ""

echo "Step 6: Configuring SELinux (if enabled)..."
if command -v getenforce &> /dev/null; then
    if [ "$(getenforce)" != "Disabled" ]; then
        echo "SELinux is enabled. Configuring permissions..."
        setsebool -P httpd_can_network_connect 1
        setsebool -P httpd_can_network_relay 1
        echo "[OK] SELinux configured"
    else
        echo "[INFO] SELinux is disabled"
    fi
else
    echo "[INFO] SELinux not available"
fi
echo ""

echo "Step 7: Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=http > /dev/null 2>&1
        firewall-cmd --permanent --add-service=https > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        echo "[OK] Firewall rules added"
    else
        echo "[INFO] Firewalld is not running"
    fi
else
    echo "[INFO] Firewalld not installed, skipping firewall configuration"
fi
echo ""

echo "Step 8: Testing Nginx configuration..."
if nginx -t; then
    echo "[OK] Configuration test passed"
else
    echo ""
    echo "[ERROR] Configuration test failed!"
    echo "Please check the error messages above and fix the configuration."
    exit 1
fi
echo ""

echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "IMPORTANT: Before starting Nginx, please:"
echo ""
echo "1. Update IIS backend server addresses in:"
echo "   $NGINX_CONF"
echo "   (Edit the upstream iis_backend section)"
echo ""
echo "2. Ensure SSL certificates are in:"
echo "   $NGINX_SSL"
echo ""
echo "3. Update server_name in:"
echo "   $NGINX_CONFD/default.conf"
echo "   (Change *.host.com to your actual domain)"
echo ""
echo "To start Nginx:"
echo "   sudo systemctl start nginx"
echo "   sudo systemctl enable nginx"
echo ""
echo "To test configuration:"
echo "   sudo nginx -t"
echo ""
echo "To reload configuration:"
echo "   sudo systemctl reload nginx"
echo ""
echo "To check status:"
echo "   sudo systemctl status nginx"
echo ""

