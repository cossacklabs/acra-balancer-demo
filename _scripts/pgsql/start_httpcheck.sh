#!/usr/bin/env sh

python3 /usr/local/bin/pgsql_http_check_daemon.py \
    -c postgresql://postgres:test@localhost/postgres?sslmode=disable &
