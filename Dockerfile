FROM oraclelinux:9

LABEL maintainer="Sergey Grigoriev <s.grigoriev@intechcore.com>"
LABEL org.opencontainers.image.description="Apache Subversion with LDAP authentication on Oracle Linux 9"

RUN dnf update -y && \
    dnf install -y \
        vim \
        mc \
        subversion \
        httpd \
        mod_dav_svn \
        mod_ldap \
        python3 \
        python3-devel \
        openldap-devel \
        gcc \
        redhat-rpm-config \
        epel-release \
        curl \
    && dnf clean all

RUN dnf install -y apachetop && dnf clean all

RUN pip3 install python-ldap && \
    ln -sf /usr/bin/python3 /usr/bin/python

RUN groupadd -g 1000 intechcore && \
    useradd -u 1000 -m -g intechcore intechcore

RUN mkdir -p /svn/repos /svn/authz && \
    chown -R intechcore:intechcore /svn && \
    chown -R intechcore:intechcore /run/httpd && \
    chown -R intechcore:intechcore /etc/httpd && \
    chown -R intechcore:intechcore /var/log/httpd

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s CMD curl --fail http://localhost:8080/ || exit 1

USER intechcore
ENTRYPOINT ["/usr/sbin/httpd", "-D", "FOREGROUND"]
