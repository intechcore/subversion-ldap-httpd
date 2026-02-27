# subversion-ldap-httpd

Apache Subversion server with LDAP authentication on Debian 13.

## Quick Start

```yaml
# docker-compose.yml
services:
  subversion:
    image: ghcr.io/intechcore/subversion-ldap-httpd:1.14.5
    ports:
      - "8080:8080"
    volumes:
      - ./repos:/svn/repos
      - ./authz:/svn/authz
      - ./apache2.conf:/etc/apache2/apache2.conf:ro
```

## Features

- Apache Subversion 1.14.5
- Apache HTTPD with mod_dav_svn
- LDAP authentication support (mod_ldap)
- Python 3 with python-ldap for LDAP sync scripts
- Runs as non-root user (intechcore:1000)
- Health check enabled

## Configuration

Mount your configuration files:

| Path | Description |
|------|-------------|
| `/etc/apache2/apache2.conf` | Main Apache config |
| `/etc/apache2/sites-enabled/*.conf` | Virtual hosts / SVN locations |
| `/svn/authz/*.authz` | SVN authorization files |
| `/svn/repos/*` | SVN repositories |

## Building Locally

```bash
make build                    # builds subversion-ldap-httpd:1.14.5
make build IMAGE_TAG=1.14.5-2 # builds with custom tag
make test                     # build + run smoke tests
make lint                     # shellcheck + hadolint
make scan                     # build + trivy vulnerability scan
```

## Testing

Tests verify image structure and end-to-end functionality (run automatically in CI):

```bash
make test    # build + run all tests (requires: docker compose, svn)
```

Checks image structure (modules, non-root user, healthcheck, svn binary), then starts a real Apache+SVN container with test repositories and verifies: checkout, commit, authz enforcement, WebDAV, and multi-repo isolation.

## Releasing New Versions

Create a git tag to trigger build, test, and push to registry:

```bash
git tag v1.14.5
git push origin v1.14.5

# For rebuilds with same SVN version
git tag v1.14.5-2
git push origin v1.14.5-2
```

Push to `main` and PRs only run build + smoke tests without pushing to registry.

## Architecture

- Multi-arch: `linux/amd64`, `linux/arm64`
- Base image: `debian:trixie-slim`
- User: `intechcore` (UID 1000)

## License

MIT
