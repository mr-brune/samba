# SMB over QUIC

This container supports **SMB over QUIC** when using `alpine:edge` as base image,
which ships `samba 4.23+` with `libngtcp2` and `libquic` bundled.

> **No kernel modules required.** QUIC runs fully in userspace via `ngtcp2`.

## How to enable

Set the environment variable `SAMBA_QUIC_ENABLE=1` in your `docker-compose.yml`.

```yaml
environment:
  SAMBA_QUIC_ENABLE: 1
```

Samba will automatically listen on **UDP/443** in addition to the standard TCP/445.

## TLS certificates

QUIC requires TLS 1.3. You have two options:

### Option A — Auto-generated self-signed cert (default)

If no certificate is found at startup, the container generates a self-signed cert automatically using `openssl`.
Useful for testing and internal networks.

Set the CN via:
```yaml
environment:
  SAMBA_QUIC_CN: mysamba.local
```

### Option B — Bring your own certificate

Mount your certs and point to them via env variables:

```yaml
environment:
  SAMBA_QUIC_CERTFILE: /etc/samba/tls/cert.pem
  SAMBA_QUIC_KEYFILE: /etc/samba/tls/key.pem
  SAMBA_QUIC_CAFILE: /etc/samba/tls/ca.pem

volumes:
  - ./certs:/etc/samba/tls:ro
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 445  | TCP      | Standard SMB |
| 443  | UDP      | SMB over QUIC |

Make sure to expose **UDP/443** on your host:

```yaml
ports:
  - "445:445/tcp"
  - "443:443/udp"
```

## Connecting from Windows

From a Windows 11 client (PowerShell):

```powershell
New-SmbMapping -LocalPath Z: -RemotePath \\mysamba.local\Share -TransportType QUIC
```

> Note: the Windows client verifies the server certificate CN/SAN.
> For production use a valid certificate (e.g. Let's Encrypt).

## Full example

See [`docker-compose.quic.yml`](../docker-compose.quic.yml) for a complete working example.
