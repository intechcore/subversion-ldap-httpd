FROM debian:trixie-slim

LABEL maintainer="Sergey Grigoriev <s.grigoriev@intechcore.com>"
LABEL org.opencontainers.image.description="Apache Subversion with LDAP authentication on Debian 13"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        vim \
        mc \
        subversion \
        apache2 \
        libapache2-mod-svn \
        libapache2-mod-authnz-external \
        python3 \
        python3-ldap \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Enable required Apache modules
RUN a2enmod dav dav_svn ldap authnz_ldap

RUN groupadd -g 1000 intechcore && \
    useradd -u 1000 -m -g intechcore intechcore

RUN mkdir -p /svn/repos /svn/authz && \
    chown -R intechcore:intechcore /svn && \
    chown -R intechcore:intechcore /run/apache2 && \
    chown -R intechcore:intechcore /var/run/apache2 && \
    chown -R intechcore:intechcore /etc/apache2 && \
    chown -R intechcore:intechcore /var/log/apache2 && \
    chown -R intechcore:intechcore /var/lock/apache2

# Set Apache to listen on 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s CMD curl --fail http://localhost:8080/ || exit 1

USER intechcore
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
