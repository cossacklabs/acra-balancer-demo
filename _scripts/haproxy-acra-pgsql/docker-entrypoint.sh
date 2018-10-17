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

listen  acraserver-rw
    bind *:9393
    option httpchk GET /
    http-check expect string OK\ :\ master
    balance roundrobin
    default-server port 9000 inter 2s downinter 5s rise 3 fall 2 slowstart 60s maxconn 256 maxqueue 128 weight 100
    server acra-server-m acra-server-m:9393 addr pgsql-master check
    server acra-server-s acra-server-s:9393 addr pgsql-slave check

listen  acraserver-ro
    bind *:9394
    option httpchk GET /
    http-check expect string OK\ :
    balance roundrobin
    default-server port 9000 inter 2s downinter 5s rise 3 fall 2 slowstart 60s maxconn 256 maxqueue 128 weight 100
    server acra-server-m acra-server-m:9393 addr pgsql-master check
    server acra-server-s acra-server-s:9393 addr pgsql-slave check
EOF

/sbin/syslogd -O /proc/1/fd/1
exec haproxy -W -db -f /usr/local/etc/haproxy/haproxy.cfg
