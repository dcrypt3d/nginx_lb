# Nginx Load Balancer Architecture Diagram

## Current Configuration: SSL Termination with Load Balancing

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT REQUESTS                              │
│                    (website.host.com, api.host.com, etc.)            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTPS (TLS 1.2/1.3)
                             │ Port 443
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         NGINX LOAD BALANCER                          │
│                    (Docker Container: nginx-lb)                     │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Port 80 (HTTP)                                               │   │
│  │  ┌────────────────────────────────────────────────────────┐  │   │
│  │  │ server_name *.host.com                                 │  │   │
│  │  │ → Redirects all HTTP to HTTPS (301)                   │  │   │
│  │  └────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Port 443 (HTTPS) - SSL TERMINATION                          │   │
│  │  ┌────────────────────────────────────────────────────────┐  │   │
│  │  │ 1. SSL/TLS Handshake                                   │  │   │
│  │  │    - TLS 1.2 or TLS 1.3                                │  │   │
│  │  │    - Strong cipher suites                              │  │   │
│  │  │    - Certificate: /etc/nginx/ssl/cert.pem              │  │   │
│  │  └────────────────────────────────────────────────────────┘  │   │
│  │                                                               │   │
│  │  ┌────────────────────────────────────────────────────────┐  │   │
│  │  │ 2. Security Headers Applied                            │  │   │
│  │  │    - HSTS, CSP, X-Frame-Options, etc.                 │  │   │
│  │  └────────────────────────────────────────────────────────┘  │   │
│  │                                                               │   │
│  │  ┌────────────────────────────────────────────────────────┐  │   │
│  │  │ 3. Rate Limiting & DoS Protection                      │  │   │
│  │  │    - 20 connections per IP                             │  │   │
│  │  │    - 10 requests/second                                 │  │   │
│  │  └────────────────────────────────────────────────────────┘  │   │
│  │                                                               │   │
│  │  ┌────────────────────────────────────────────────────────┐  │   │
│  │  │ 4. Load Balancing Decision                             │  │   │
│  │  │    upstream iis_backend {                                │  │   │
│  │  │      ip_hash;  ← STICKY SESSIONS                        │  │   │
│  │  │      server iis-host1:443;                              │  │   │
│  │  │      server iis-host2:443;                              │  │   │
│  │  │    }                                                     │  │   │
│  │  │                                                          │  │   │
│  │  │  Routing Logic:                                         │  │   │
│  │  │  - Client IP → Hash → Same backend server              │  │   │
│  │  │  - Example: 192.168.1.100 → Always → iis-host1        │  │   │
│  │  │  - Example: 192.168.1.101 → Always → iis-host2        │  │   │
│  │  └────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTPS (Re-encrypted)
                             │ Port 443
                             │ TLS 1.2/1.3
                             │ Certificate Verified
                             │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
┌───────────────────────────┐  ┌───────────────────────────┐
│      IIS SERVER 1         │  │      IIS SERVER 2         │
│    (iis-host1:443)        │  │    (iis-host2:443)        │
│                           │  │                           │
│  ┌─────────────────────┐ │  │  ┌─────────────────────┐ │
│  │ SSL Certificate     │ │  │  │ SSL Certificate     │ │
│  │ (Terminates SSL)    │ │  │  │ (Terminates SSL)    │ │
│  └─────────────────────┘ │  │  └─────────────────────┘ │
│                           │  │                           │
│  ┌─────────────────────┐ │  │  ┌─────────────────────┐ │
│  │ Application Logic   │ │  │  │ Application Logic   │ │
│  │ (Your Web App)      │ │  │  │ (Your Web App)      │ │
│  └─────────────────────┘ │  │  └─────────────────────┘ │
└───────────────────────────┘  └───────────────────────────┘
```

## Data Flow Example

### Request Flow: Client → Nginx → IIS

```
1. CLIENT REQUEST
   └─> GET https://website.host.com/api/data
       └─> TLS 1.3 Handshake
           └─> Certificate Validation

2. NGINX (Port 443)
   ├─> SSL Termination (Decrypts)
   ├─> Security Headers Added
   ├─> Rate Limiting Check
   ├─> Load Balancing Decision (ip_hash)
   │   └─> Client IP: 192.168.1.100
   │       └─> Hash → Routes to: iis-host1
   └─> Re-encrypts for backend

3. BACKEND CONNECTION
   └─> HTTPS → iis-host1:443
       ├─> TLS Handshake (New)
       ├─> Certificate Verification (proxy_ssl_verify on)
       └─> Request Forwarded

4. IIS SERVER 1
   ├─> SSL Termination
   ├─> Processes Request
   └─> Returns Response

5. RESPONSE PATH (Reverse)
   └─> IIS → Nginx → Client
       └─> All encrypted with TLS
```

## Key Components

### 1. SSL Termination Layer
```
Client (HTTPS) → Nginx (Terminates SSL) → Backend (HTTPS)
                ↑
            Certificate: *.host.com
            TLS 1.2/1.3 Only
            Strong Ciphers
```

### 2. Load Balancing Algorithm
```
ip_hash Method:
┌─────────────┐
│ Client IP   │ → Hash Function → Backend Server
│ 192.168.1.x │                    (Consistent)
└─────────────┘
```

### 3. Sticky Sessions
```
Session 1: Client A (IP: 1.2.3.4) → Always → IIS Server 1
Session 2: Client B (IP: 5.6.7.8) → Always → IIS Server 2
Session 3: Client A (IP: 1.2.3.4) → Always → IIS Server 1 ✓
```

## Security Layers

```
┌─────────────────────────────────────────┐
│ Layer 1: Client → Nginx                │
│ - TLS 1.2/1.3 Encryption                │
│ - Certificate Validation                │
│ - Strong Cipher Suites                 │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Layer 2: Nginx Processing               │
│ - Rate Limiting (DoS Protection)        │
│ - Security Headers (HSTS, CSP, etc.)    │
│ - File Access Restrictions              │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Layer 3: Nginx → Backend                │
│ - TLS 1.2/1.3 Re-encryption             │
│ - Certificate Verification              │
│ - SNI Support                           │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Layer 4: IIS Backend                    │
│ - SSL Termination                       │
│ - Application Processing                │
└─────────────────────────────────────────┘
```

## Port Flow

```
Internet
   │
   │ Port 443 (HTTPS)
   ▼
┌──────────────┐
│   NGINX      │ Port 80 (HTTP) → Redirects to 443
│  Load Balancer│ Port 443 (HTTPS) → SSL Termination
└──────┬───────┘
       │
       │ Port 443 (HTTPS)
       ├──────────────┬──────────────┐
       │              │              │
       ▼              ▼              ▼
  ┌─────────┐   ┌─────────┐   ┌─────────┐
  │ IIS-1   │   │ IIS-2   │   │ IIS-3   │ (Optional Backup)
  │ :443    │   │ :443    │   │ :443    │
  └─────────┘   └─────────┘   └─────────┘
```

## Request Distribution Example

```
Time    Client IP        Request              Backend Selected
─────────────────────────────────────────────────────────────
T1      192.168.1.10    GET /page1           → IIS Server 1
T2      192.168.1.20    GET /page2           → IIS Server 2
T3      192.168.1.10    GET /page3           → IIS Server 1 (sticky)
T4      192.168.1.30    GET /api/data        → IIS Server 1 (hash)
T5      192.168.1.20    POST /api/submit     → IIS Server 2 (sticky)
```

## Configuration Files Mapping

```
┌─────────────────────────────────────────┐
│ docker-compose.yml                      │
│ - Defines Nginx container               │
│ - Maps ports 80, 443                   │
│ - Mounts config files                   │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ nginx.conf                              │
│ - Main configuration                    │
│ - Upstream definition (iis_backend)    │
│ - Rate limiting zones                   │
│ - HTTP → HTTPS redirect                 │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ conf.d/default.conf                     │
│ - SSL termination config                │
│ - Security headers                      │
│ - Proxy settings                        │
│ - Backend routing                       │
└─────────────────────────────────────────┘
```

## Summary

**Current Setup:**
- ✅ SSL Termination at Nginx
- ✅ Load Balancing (2 IIS servers)
- ✅ Sticky Sessions (ip_hash)
- ✅ HTTPS Backend Connections
- ✅ NIST-Aligned Security
- ✅ Rate Limiting & DoS Protection

**Traffic Flow:**
1. Client connects via HTTPS to Nginx
2. Nginx terminates SSL, applies security
3. Nginx load balances using ip_hash
4. Nginx re-encrypts and forwards to IIS backend
5. IIS processes request and returns response
6. Response flows back through Nginx to client

