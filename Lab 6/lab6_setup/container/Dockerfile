FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections && \
    apt-get update && apt-get install -y --no-install-recommends \
      firefox gedit dbus-x11 x11-utils \
      wireshark tshark libcap2-bin \
      iproute2 iptables iputils-ping net-tools \
      dnsutils openssh-client openssh-server sshpass \
      python3 sudo nano vim less procps jq \
      ca-certificates wget tcpdump netcat-openbsd util-linux \
      && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash seed && \
    echo 'seed:toor' | chpasswd && \
    echo 'root:toor' | chpasswd && \
    usermod -aG sudo,wireshark seed && \
    printf 'seed ALL=(ALL) ALL\n' > /etc/sudoers.d/seed && chmod 0440 /etc/sudoers.d/seed && \
    mkdir -p /run/sshd /workspace /logs /shared /opt/lab/scripts /opt/lab/firefox /usr/local/libexec && \
    chown -R seed:seed /workspace /logs /shared /home/seed

RUN sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap || true

COPY container/node-init.sh /usr/local/bin/node-init.sh
COPY container/lab-dns-proxy.py /usr/local/bin/lab-dns-proxy.py
COPY container/firefox-wrapper.sh /usr/local/bin/firefox
COPY container/firefox-as-seed.sh /usr/local/libexec/firefox-as-seed
COPY container/wireshark-wrapper.sh /usr/local/bin/wireshark
COPY container/gedit-wrapper.sh /usr/local/bin/gedit
RUN chmod +x /usr/local/bin/node-init.sh /usr/local/bin/lab-dns-proxy.py /usr/local/bin/firefox \
    /usr/local/libexec/firefox-as-seed /usr/local/bin/wireshark /usr/local/bin/gedit

# Prefer the nftables backend on modern Linux kernels. start.sh still tests both
# nft and legacy backends at runtime and chooses whichever actually works.
RUN if [ -x /usr/sbin/iptables-nft ]; then \
      update-alternatives --set iptables /usr/sbin/iptables-nft || true; \
      update-alternatives --set ip6tables /usr/sbin/ip6tables-nft || true; \
    fi

USER root

CMD ["/usr/local/bin/node-init.sh"]
