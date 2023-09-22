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


COPY _scripts/pgsql/configure_replication.sh /docker-entrypoint-initdb.d/
RUN chmod 0755 /docker-entrypoint-initdb.d/*.sh

RUN mkdir -p /app/docker
COPY replication-setup.entry.sh /app/docker/entry.sh
RUN chmod +x /app/docker/entry.sh

WORKDIR /app
ENTRYPOINT ["/app/docker/entry.sh"]
