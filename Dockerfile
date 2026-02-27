FROM debian:stable-slim

LABEL maintainer="Sergey Grigoriev <s.grigoriev@intechcore.com>"
LABEL org.opencontainers.image.description="Apache Subversion with LDAP authentication on Debian 13"

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
RUN groupadd -g 1000 intechcore && \
    useradd -u 1000 -m -g intechcore intechcore

# Configure Apache to run as intechcore and listen on 8080
RUN sed -i 's/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=intechcore/' /etc/apache2/envvars && \
    sed -i 's/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=intechcore/' /etc/apache2/envvars && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

# Create directories and set permissions
RUN mkdir -p /svn/repos /var/run/apache2 /var/lock/apache2 && \
    chown -R intechcore:intechcore /svn && \
    chown -R intechcore:intechcore /run/apache2 && \
    chown -R intechcore:intechcore /var/run/apache2 && \
    chown -R intechcore:intechcore /etc/apache2 && \
    chown -R intechcore:intechcore /var/log/apache2 && \
    chown -R intechcore:intechcore /var/lock/apache2 && \
    chown -R intechcore:intechcore /var/www/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

USER intechcore
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
