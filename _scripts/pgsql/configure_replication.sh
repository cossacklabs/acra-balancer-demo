#!/bin/bash

set -euo pipefail

set_pg_option() {
    if grep -q "$1" "$PGDATA/postgresql.conf"; then
        sed -i "s/^#*${1}\\s*=.*/${1} = ${2}/g" "$PGDATA/postgresql.conf"
    else
        echo "${1} = ${2}" >> "$PGDATA/postgresql.conf"
    fi
}

if [ -z "${POSTGRES_REPLICATION_MASTER_HOST:-}" ]; then
    # master
    set_pg_option "wal_level" "hot_standby"
    set_pg_option "synchronous_commit" "local"
    set_pg_option "max_wal_senders" "${POSTGRES_MAX_WAL_SENDERS:-4}"
    set_pg_option "wal_keep_segments" "${POSTGRES_WAL_KEEP_SEGMENTS:-10}"
    set_pg_option "hot_standby" "on"

    psql -v ON_ERROR_STOP=1 --username postgres <<EOSQL
CREATE USER $POSTGRES_REPLICATION_USER REPLICATION LOGIN ENCRYPTED PASSWORD '$POSTGRES_REPLICATION_PASSWORD';
EOSQL

else
    # slave
    set_pg_option "wal_level" "hot_standby"
    set_pg_option "synchronous_commit" "local"
    set_pg_option "max_wal_senders" "${POSTGRES_MAX_WAL_SENDERS:-4}"
    set_pg_option "wal_keep_segments" "${POSTGRES_WAL_KEEP_SEGMENTS:-10}"
    set_pg_option "hot_standby" "on"

    cat > ${PGDATA}/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'host=${POSTGRES_REPLICATION_MASTER_HOST} port=5432 user=${POSTGRES_REPLICATION_USER} password=${POSTGRES_REPLICATION_PASSWORD}'
trigger_file = '/tmp/postgresql.trigger.5432'
EOF

    chown postgres ${PGDATA}/recovery.conf
    chmod 600 ${PGDATA}/recovery.conf
fi
