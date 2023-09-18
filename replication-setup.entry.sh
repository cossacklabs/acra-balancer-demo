#!/usr/bin/env bash

set -Eeuo pipefail

echo 'Waiting for master PostgreSQL... '
while ! pg_isready -h $POSTGRES_HOST -p 5432; do
    sleep 1
done

# do master backup
pg_basebackup -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER \
-D /var/lib/postgresql/data/ -Fp -Xs -P

# configure slave
/bin/bash /docker-entrypoint-initdb.d/configure_replication.sh

