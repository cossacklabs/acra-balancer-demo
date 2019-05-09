FROM haproxy:1.8-alpine

# Include metadata, additionally use label-schema namespace
LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.vendor="Cossack Labs" \
    org.label-schema.url="https://cossacklabs.com" \
    org.label-schema.name="Acra + HAProxy + PostgreSQL Demo" \
    org.label-schema.description="Demonstrates HA and balancing between Acra instances" \
    com.cossacklabs.product.name="acra-haproxy-pgsql" \
    com.cossacklabs.product.component="haproxy-pgsql" \
    com.cossacklabs.docker.container.type="product"

# Fix CVE-2019-5021
RUN echo 'root:!' | chpasswd -e

EXPOSE 5432 5433

COPY _scripts/haproxy-pgsql/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD []
