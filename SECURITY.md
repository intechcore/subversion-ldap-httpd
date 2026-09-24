# Security policy

## Reporting a vulnerability

Report a vulnerability privately through GitHub:
https://github.com/intechcore/subversion-ldap-httpd/security/advisories/new
(the **Security** tab, **Report a vulnerability**). Do not open a public issue for it.

We answer within a week. The fix goes into the next release, and its release notes name it.

## Supported versions

Only the latest image, `ghcr.io/intechcore/subversion-ldap-httpd:latest`, gets fixes. Automatic
releases pick up fixed packages and base image updates.

## Scope

The image: the Dockerfile, the Apache and Subversion configuration it ships, the tests and the
workflows.

Vulnerabilities in upstream software (Apache httpd, Subversion, the Debian packages and the
`debian:trixie-slim` base image) belong to the upstream project. Tell us as well if this project
is affected, so we can release a fix when the upstream fix is out.
