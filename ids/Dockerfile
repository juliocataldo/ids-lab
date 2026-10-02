FROM jasonish/suricata:7.0
RUN dnf install -y iptables-nft && dnf clean all
COPY stop-suricata.sh /usr/local/bin/stop-suricata
RUN chmod +x /usr/local/bin/stop-suricata
