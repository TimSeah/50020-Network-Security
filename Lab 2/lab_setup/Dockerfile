FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        dbus-x11 \
        gedit \
        inetutils-telnet \
        inetutils-telnetd \
        iproute2 \
        iputils-ping \
        libcap2-bin \
        net-tools \
        netcat-openbsd \
        openbsd-inetd \
        openssh-client \
        openssh-server \
        procps \
        python3 \
        python3-scapy \
        tcpdump \
        tshark \
        util-linux \
        wireshark \
        xauth \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN useradd --create-home --shell /bin/bash kali && \
    echo 'kali:kali' | chpasswd && \
    echo 'root:toor' | chpasswd

RUN chmod 0755 /usr/bin/dumpcap && \
    setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap

RUN mkdir -p /run/sshd /etc/ssh/sshd_config.d /shared && \
    printf '%s\n' \
        'PasswordAuthentication yes' \
        'PermitRootLogin yes' \
        'UsePAM yes' \
        > /etc/ssh/sshd_config.d/99-tcp-lab.conf

RUN printf '%s\n' \
    'telnet stream tcp nowait root /usr/sbin/telnetd telnetd' \
    > /etc/inetd.conf

COPY entrypoint.sh /usr/local/sbin/lab-entrypoint
COPY wireshark-wrapper /usr/local/bin/wireshark
COPY gedit-wrapper /usr/local/bin/gedit

RUN chmod 0755 \
    /usr/local/sbin/lab-entrypoint \
    /usr/local/bin/wireshark \
    /usr/local/bin/gedit

EXPOSE 22 23 6666

ENTRYPOINT ["/usr/local/sbin/lab-entrypoint"]
