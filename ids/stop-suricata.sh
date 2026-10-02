#!/bin/sh
# Para o Suricata e espera ele realmente encerrar (evita erro de pidfile).
pkill -x suricata 2>/dev/null
while pgrep -x suricata >/dev/null 2>&1; do sleep 1; done
rm -f /var/run/suricata.pid
echo "Suricata parado."
