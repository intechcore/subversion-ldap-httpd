# subversion-ldap-httpd

Apache Subversion server with LDAP authentication on Oracle Linux 9.

## Quick Start

```yaml
# docker-compose.yml
services:
  subversion:
    image: ghcr.io/intechcore/subversion-ldap-httpd:1.14.1
    ports:
      - "8080:8080"
    volumes:
      - ./repos:/svn/repos
      - ./authz:/svn/authz
      - ./httpd.conf:/etc/httpd/conf/httpd.conf:ro
```

## Features

- Apache Subversion 1.14.1
- Apache HTTPD with mod_dav_svn
- LDAP authentication support (mod_ldap)
- Python 3 with python-ldap for LDAP sync scripts
- Runs as non-root user (intechcore:1000)
- Health check enabled

## Configuration

Mount your configuration files:

| Path | Description |
|------|-------------|
| `/etc/httpd/conf/httpd.conf` | Main Apache config |
| `/etc/httpd/conf.d/*.conf` | Virtual hosts / SVN locations |
| `/svn/authz/*.authz` | SVN authorization files |
| `/svn/repos/*` | SVN repositories |

## Building Locally

```bash
./build.sh         # builds subversion-ldap-httpd:1.14.1
./build.sh 1.14.1-2  # builds with custom tag
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `1.14.1` | Subversion 1.14.1 on Oracle Linux 9 |
| `main` | Latest build from main branch |

## Building New Version

Create a git tag:

```bash
git tag v1.14.1
git push origin v1.14.1

# For rebuilds with same SVN version
git tag v1.14.1-2
git push origin v1.14.1-2
```

GitHub Actions will automatically build and publish:
- `ghcr.io/intechcore/subversion-ldap-httpd:1.14.1`
- `ghcr.io/intechcore/subversion-ldap-httpd:1.14.1-2`

## Architecture

- Multi-arch: `linux/amd64`, `linux/arm64`
- Base image: `oraclelinux:9`
- User: `intechcore` (UID 1000)

## License

MIT
