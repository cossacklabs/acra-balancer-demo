FROM postgres:13

# Include metadata, additionally use label-schema namespace
LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.vendor="Cossack Labs" \
    org.label-schema.url="https://cossacklabs.com" \
    org.label-schema.name="Acra + HAProxy + PostgreSQL Demo" \
    org.label-schema.description="Demonstrates HA and balancing between Acra instances" \
    com.cossacklabs.product.name="acra-haproxy-pgsql" \
    com.cossacklabs.product.component="pgsql-replication" \
    com.cossacklabs.docker.container.type="product"


COPY ssl/pgsql-slave/pgsql-slave.crt /tmp.ssl/server.crt
COPY ssl/pgsql-slave/pgsql-slave.key /tmp.ssl/server.key
COPY ssl/ca/ca.crt /tmp.ssl/root.crt
RUN chown -R postgres:postgres /tmp.ssl

COPY _scripts/pgsql/pgsql_http_check_daemon.py /usr/local/bin/

COPY _scripts/pgsql/start_httpcheck.sh /docker-entrypoint-initdb.d/
COPY _scripts/pgsql/postgresql-ssl-configure.sh /docker-entrypoint-initdb.d/

RUN chmod 0755 /docker-entrypoint-initdb.d/*.sh

COPY _scripts/pgsql/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh
