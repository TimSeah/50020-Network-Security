FROM kalilinux/kali-rolling

ARG DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1

RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod 0755 /usr/sbin/policy-rc.d \
    && printf 'wireshark-common wireshark-common/install-setuid boolean true\n' | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       ca-certificates \
       iproute2 \
       iputils-ping \
       net-tools \
       dnsutils \
       bind9 \
       bind9-utils \
       tcpdump \
       wireshark \
       tshark \
       curl \
       wget \
       inetutils-telnet \
       openssh-client \
       openssh-server \
       python3 \
       python3-pip \
       python3-venv \
       python3-scapy \
       gedit \
       nano \
       vim \
       sudo \
       procps \
       lsof \
       iptables \
       nftables \
       nginx \
       xauth \
       dbus-x11 \
       libcap2-bin \
    && rm -rf /var/lib/apt/lists/* \
    && (setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap || true)

COPY config /opt/dns-lab/config
COPY scripts /opt/dns-lab/scripts
COPY web /opt/dns-lab/web
COPY zones /opt/dns-lab/zones
COPY zones/db.attackerpage.com /etc/bind/db.attackerpage.com
COPY zones/db.example.com /etc/bind/db.example.com

RUN chmod 0755 /opt/dns-lab/scripts/*.sh /opt/dns-lab/scripts/dns_ids /opt/dns-lab/scripts/flushcache /opt/dns-lab/scripts/dumpcache /opt/dns-lab/scripts/reloadzone /opt/dns-lab/scripts/dnssec-* \
    && ln -sf /opt/dns-lab/scripts/dns_ids /usr/local/bin/dns_ids \
    && ln -sf /opt/dns-lab/scripts/flushcache /usr/local/bin/flushcache \
    && ln -sf /opt/dns-lab/scripts/dumpcache /usr/local/bin/dumpcache \
    && ln -sf /opt/dns-lab/scripts/reloadzone /usr/local/bin/reloadzone \
    && ln -sf /opt/dns-lab/scripts/dnssec-status /usr/local/bin/dnssec-status \
    && ln -sf /opt/dns-lab/scripts/dnssec-on /usr/local/bin/dnssec-on \
    && ln -sf /opt/dns-lab/scripts/dnssec-off /usr/local/bin/dnssec-off \
    && mkdir -p /run/named /var/cache/bind /var/log/lab \
    && chown -R bind:bind /run/named /var/cache/bind \
    && rndc-confgen -a -c /etc/bind/rndc.key -k rndc-key >/dev/null 2>&1 \
    && chown root:bind /etc/bind/rndc.key \
    && chmod 0640 /etc/bind/rndc.key \
    && printf 'dnssec-validation no;\n' > /etc/bind/lab-dnssec.conf \
    && named-checkconf /opt/dns-lab/config/node2/named.conf \
    && named-checkconf -z /opt/dns-lab/config/node4/named.conf \
    && named-checkzone attackerpage.com /etc/bind/db.attackerpage.com \
    && named-checkzone example.com /etc/bind/db.example.com \
    && python3 -m py_compile /opt/dns-lab/scripts/dumpcache.py \
    && rm -f /etc/bind/rndc.key /etc/bind/lab-dnssec.conf

ENTRYPOINT ["/opt/dns-lab/scripts/entrypoint.sh"]
