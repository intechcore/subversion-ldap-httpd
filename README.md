# subversion-ldap-httpd

Apache Subversion server with LDAP authentication on Debian 13.

## Quick Start

```yaml
# docker-compose.yml
services:
  subversion:
    # renovate: image=ghcr.io/intechcore/subversion-ldap-httpd
    image: ghcr.io/intechcore/subversion-ldap-httpd:1.14.5-2
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
- Runs as non-root user (subversion:1000)
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

Run the **Release** workflow (`workflow_dispatch`). It builds and tests the image on amd64 and
arm64, each on its own job, pushes exactly the tested images, reads
the Subversion version from the image, and pushes `<version>-<n>`, `<version>` and `latest` to
ghcr.io. `<n>` counts the builds for one Subversion version.

Pull requests and pushes to `main` run `ci.yml`: lint (ShellCheck, Hadolint, actionlint, zizmor,
`trivy config`), the integration tests on amd64 and arm64, and a Trivy scan of the image.
Trivy fails on CRITICAL findings and reports HIGH ones to a tracking issue.

### Automatic Rebuilds

The image builds on `debian:trixie-slim` and installs its packages with apt. Debian ships security fixes as package updates and rebuilds the base image under the same tag. Renovate sees neither.

The `Rebuild` workflow checks the published `latest` image every Monday. It releases the next build (`1.14.5-1 → 1.14.5-2`) in two cases:

- The upstream base image digest differs from the `org.opencontainers.image.base.digest` label of the published image.
- Trivy finds fixable CRITICAL or HIGH vulnerabilities in the published image.

A rebuild runs without the layer cache, so apt installs current packages. The release notes state the reason. The rebuild releases the current `main`, so merged changes go out with it.

The base stays on the Debian 13 codename on purpose. `stable-slim` moves to the next Debian release without notice. Move to Debian 14 by changing `FROM`.

## Architecture

- Multi-arch: `linux/amd64`, `linux/arm64`
- Base image: `debian:trixie-slim`
- User: `subversion` (UID 1000)

## License

MIT
