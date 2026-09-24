# Changelog

All notable changes to this image are recorded here. The format is loosely based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Image tags are
`<Subversion version>-<n>`; `<n>` counts the builds for one Subversion version.

## [Unreleased]

### Added
- A real LDAP authentication test: Apache binds against an OpenLDAP server from
  `ghcr.io/intechcore/openldap` and lets an LDAP user in, a wrong password gets 401. Until now the
  tests only checked that the LDAP modules were enabled.
- A test that python-ldap imports.
- `tests/contract.sh`: every feature and configuration path in the README must have a test. Runs
  in the lint job.
- Build provenance and SBOM attestations for every release, checked with `gh attestation verify`. OpenSSF Scorecard workflow and README badges. arm64 builds and tests run on native runners instead of QEMU.
- `SECURITY.md`, `CONTRIBUTING.md` and `.editorconfig`.
- OCI labels: title, source, documentation, licenses, vendor, authors, revision and created.

### Changed
- Releases are automatic. The Rebuild workflow also runs on each push to `main` that changes the
  `Dockerfile`, and releases a change of it since the commit of the published image. A merged
  Renovate update of the base image now reaches the registry without a manual step.
- Renovate takes its common rules from the shared preset `github>intechcore/renovate-config`, which also turns on OSV vulnerability alerts.
- Release notes summarize the release for people instead of listing the commits. They start with
  the rebuild reason or the Subversion update, then the CHANGELOG entries added since the previous
  release, then a table of Subversion and the base image. The commits follow in a collapsed block.
  `.github/scripts/release-notes.sh` writes them.
- The weekly rebuild names each Trivy finding it fixes in the release notes: CVE, package,
  installed and fixed version.
- CI cancels the older run of a pull request on a new push, and every job has a time limit.
- The Trivy summary and tracking issue come from a local action, the same in each intechcore
  image repository.
- ShellCheck runs a pinned version that Renovate updates.
- `SECURITY.md`, `CONTRIBUTING.md` and `.editorconfig` follow the shared templates. The changelog
  keeps one Unreleased section; older per-release sections moved below.

### Fixed
- The Rebuild workflow never started since releases are signed: it called the release without
  the `id-token` and `attestations` permissions the release needs. It grants them now.
- A release counts the git tags as taken build numbers, next to the package tags, and never
  attaches to an existing tag. A deleted package or release can no longer free a number.
- A release fails when the package API cannot list the published tags, instead of counting from
  an empty list.

## History before automatic releases

The images up to 1.14.5-2 were released by hand. Later releases take their notes from the
Unreleased section above.

### 1.14.5-2 - 2026-09-23

#### Added
- Weekly `Rebuild` workflow. It releases the next build when the `debian:trixie-slim` base image
  was rebuilt under the same tag, or when Trivy finds fixable CRITICAL or HIGH vulnerabilities in
  the published image.
- Renovate tracks the exact image tag in the README.
- One `ci.yml`: ShellCheck, Hadolint, actionlint, zizmor, `trivy config`, the integration tests
  on amd64 and arm64, and a Trivy scan. CRITICAL fails the build, HIGH goes to a tracking issue.

#### Changed
- Base image `debian:stable-slim` → `debian:trixie-slim`, so an automatic rebuild never moves to
  the next Debian release.
- GitHub Actions are pinned by commit SHA.
- The Release workflow builds and tests each architecture on its own job and pushes exactly the
  tested image. Before, arm64 was published without a test.

### 1.14.5-1

First release on ghcr.io: Apache Subversion with LDAP authentication on Debian 13.
