FROM debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

LABEL org.opencontainers.image.title="subversion-ldap-httpd" \
      org.opencontainers.image.description="Apache Subversion with LDAP authentication on Debian 13" \
      org.opencontainers.image.source="https://github.com/intechcore/subversion-ldap-httpd" \
      org.opencontainers.image.documentation="https://github.com/intechcore/subversion-ldap-httpd/blob/main/README.md" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Intechcore GmbH" \
      org.opencontainers.image.authors="Sergey Grigoriev <s.grigoriev@intechcore.com>"

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        vim \
        mc \
        subversion \
        apache2 \
        libapache2-mod-svn \
        python3 \
        python3-ldap \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # Enable required Apache modules
    && a2enmod dav dav_svn ldap authnz_ldap headers rewrite \
    # Disable default site
    && a2dissite 000-default

# Create user
RUN groupadd -g 1000 subversion && \
    useradd -u 1000 -m -g subversion subversion

# Configure Apache to run as subversion and listen on 8080
RUN sed -i 's/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=subversion/' /etc/apache2/envvars && \
    sed -i 's/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=subversion/' /etc/apache2/envvars && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

# Create directories and set permissions
RUN mkdir -p /svn/repos /var/run/apache2 /var/lock/apache2 && \
    chown -R subversion:subversion /svn && \
    chown -R subversion:subversion /run/apache2 && \
    chown -R subversion:subversion /var/run/apache2 && \
    chown -R subversion:subversion /etc/apache2 && \
    chown -R subversion:subversion /var/log/apache2 && \
    chown -R subversion:subversion /var/lock/apache2 && \
    chown -R subversion:subversion /var/www/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["curl", "-f", "http://localhost:8080/"]

# Build metadata and the base image the build started from, passed in by the
# release workflow. The weekly rebuild compares the base digest with the
# current upstream one.
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG BASE_IMAGE=unknown
ARG BASE_DIGEST=unknown
LABEL org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="${BASE_IMAGE}" \
      org.opencontainers.image.base.digest="${BASE_DIGEST}"

USER 1000:1000
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
