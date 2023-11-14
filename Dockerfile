# Dockerfile for icinga2 with icingaweb2
# https://github.com/jjethwa/icinga2

FROM debian:bookworm

ENV APACHE2_HTTP=REDIRECT \
    ICINGA2_FEATURE_GRAPHITE=false \
    ICINGA2_FEATURE_GRAPHITE_HOST=graphite \
    ICINGA2_FEATURE_GRAPHITE_PORT=2003 \
    ICINGA2_FEATURE_GRAPHITE_URL=http://graphite \
    ICINGA2_FEATURE_GRAPHITE_SEND_THRESHOLDS="true" \
    ICINGA2_FEATURE_GRAPHITE_SEND_METADATA="false" \
    ICINGA2_USER_FULLNAME="Icinga2" \
    ICINGA2_FEATURE_DIRECTOR="true" \
    ICINGA2_FEATURE_DIRECTOR_KICKSTART="true" \
    ICINGA2_FEATURE_DIRECTOR_USER="icinga2-director" \
    ICINGA2_LOG_LEVEL="information" \
    MYSQL_ROOT_USER=root

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    apache2 \
    apt-transport-https \
    ca-certificates \
    curl \
    dnsutils \
    file \
    gnupg \
    jq \
    libdbd-mysql-perl \
    libdigest-hmac-perl \
    libnet-snmp-perl \
    locales \
    logrotate \
    lsb-release \
    bsd-mailx \
    mariadb-client \
    mariadb-server \
    netbase \
    openssh-client \
    openssl \
    php-curl \
    php-ldap \
    php-mysql \
    php-mbstring \
    php-gmp \
    procps \
    pwgen \
    python3 \
    python3-requests \
    snmp \
    msmtp \
    sudo \
    supervisor \
    telnet \
    unzip \
    wget \
    cron \
    && apt-get -y --purge remove exim4 exim4-base exim4-config exim4-daemon-light \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ARG GITREF_MODDIRECTOR=1.11.0-1+debian12

RUN export DEBIAN_FRONTEND=noninteractive \
    && curl -s https://packages.icinga.com/icinga.key \
    | apt-key add - \
    && echo "deb https://packages.icinga.com/debian icinga-$(lsb_release -cs) main" > /etc/apt/sources.list.d/$(lsb_release -cs)-icinga.list \
    && echo "deb-src https://packages.icinga.com/debian icinga-$(lsb_release -cs) main" >> /etc/apt/sources.list.d/$(lsb_release -cs)-icinga.list \
    && echo "deb http://deb.debian.org/debian $(lsb_release -cs)-backports main" > /etc/apt/sources.list.d/$(lsb_release -cs)-backports.list \
    && apt-get update \
    && apt-get install -y --install-recommends \
    icinga2 \
    icinga2-ido-mysql \
    icingacli \
    icingaweb2 \
    icinga-director=${GITREF_MODDIRECTOR} \
    icinga-director-web=${GITREF_MODDIRECTOR} \
    monitoring-plugins \
    nagios-nrpe-plugin \
    nagios-plugins-contrib \
    nagios-snmp-plugins \
    libmonitoring-plugin-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# waiting for new release of the lib: https://github.com/Icinga/icinga-php-library/issues/28
ARG INSTALL_VERSION="snapshot/nightly"
RUN rm -fr /usr/share/icinga-php/ipl/ && mkdir -p /usr/share/icinga-php/ipl/ \
    && wget -q "https://github.com/Icinga/icinga-php-library/archive/$INSTALL_VERSION.tar.gz" -O - \
   | tar xfz - -C /usr/share/icinga-php/ipl/ --strip-components 1


COPY content/ /

# Final fixes
RUN true \
    && sed -i 's/vars\.os.*/vars.os = "Docker"/' /etc/icinga2/conf.d/hosts.conf \
    && mv /etc/icingaweb2/ /etc/icingaweb2.dist \
    && mv /etc/icinga2/ /etc/icinga2.dist \
    && mkdir -p /etc/icinga2 \
    && usermod -aG icingaweb2,nagios www-data \
    && usermod -aG icingaweb2 nagios \
    && mkdir -p /var/log/icinga2 \
    && chmod 755 /var/log/icinga2 \
    && chown nagios:nagios /var/log/icinga2 \
    && mkdir -p /var/cache/icinga2 \
    && chmod 755 /var/cache/icinga2 \
    && chown nagios:nagios /var/cache/icinga2 \
    && touch /var/log/cron.log \
    && rm -rf \
    /var/lib/mysql/* \
    && chmod u+s,g+s \
    /bin/ping \
    /bin/ping6 \
    /usr/lib/nagios/plugins/check_icmp \
    && /sbin/setcap cap_net_raw+p /bin/ping

EXPOSE 80 443 5665

# Initialize and run Supervisor
ENTRYPOINT ["/opt/run"]

