#!/bin/sh

set -euo pipefail

cat > /etc/rsyslog.conf <<'EOF'
$ModLoad imudp
$UDPServerAddress 0.0.0.0
$UDPServerRun 514
local0.* -/var/log/haproxy.log
& ~
EOF

cat > /usr/local/etc/haproxy/haproxy.cfg <<'EOF'
global
    maxconn 256
    log /dev/log local0

defaults
    log global
    mode tcp
    timeout connect 5s
    timeout client 10800s
    timeout server 10800s

listen acraserver-rw
    bind *:9393
    balance roundrobin
    server acra-server-m acra-server-m:9393
    server acra-server-s acra-server-s:9393

listen acraserver-ro
    bind *:9394
    balance roundrobin
    server acra-server-m acra-server-m:9393
    server acra-server-s acra-server-s:9393
EOF

/sbin/syslogd -O /proc/1/fd/1
exec haproxy -W -db -f /usr/local/etc/haproxy/haproxy.cfg
