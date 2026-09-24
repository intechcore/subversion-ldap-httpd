# Security policy

## Reporting a vulnerability

Report a vulnerability privately through GitHub:
https://github.com/intechcore/subversion-ldap-httpd/security/advisories/new
(the **Security** tab, **Report a vulnerability**). Do not open a public issue for it.

We answer within a week. The fix goes into the next image release, and the GitHub release notes
name it.

## Supported versions

Only the latest image, `ghcr.io/intechcore/subversion-ldap-httpd:latest`, gets fixes. The weekly rebuild picks up fixed Debian packages
and base image updates on its own, see the README.

## Scope

The image: the Dockerfile, the Apache and Subversion configuration it ships, and the release workflows.

Vulnerabilities in the upstream software (Apache httpd, Subversion, Debian packages) belong to the upstream project. Tell us as
well if the image is affected, so we can release a fixed image when the upstream fix is out.
