FROM alpine:3.15.0

# Include metadata, additionally use label-schema namespace
LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.vendor="Cossack Labs" \
    org.label-schema.url="https://cossacklabs.com" \
    org.label-schema.name="Acra + HAProxy + PostgreSQL Demo" \
    org.label-schema.description="Demonstrates HA and balancing between Acra instances" \
    com.cossacklabs.product.name="acra-haproxy-pgsql" \
    com.cossacklabs.product.component="acra-python-example" \
    com.cossacklabs.docker.container.type="product"

# Fix CVE-2019-5021
RUN echo 'root:!' | chpasswd -e

RUN apk update

RUN apk add --no-cache bash python3 py3-pip postgresql-dev postgresql-client
RUN pip3 install --no-cache-dir --upgrade pip
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN apk add gcc python3-dev musl-dev libxml2-dev git alpine-sdk rsync

# TODO : remove when themis will fully support alpine
RUN mkdir -p /usr/local/sbin
RUN echo -e '#!/bin/sh\n\nexit 0\n' > /usr/local/sbin/ldconfig
RUN chmod +x /usr/local/sbin/ldconfig

# themis
RUN cd /root \
    && git clone --depth 1 -b stable https://github.com/cossacklabs/themis
RUN cd /root/themis \
    && make \
    && make install \
    && make pythemis_install

# acra
# using commit instead of version/tag to use the commit with specific SqlAlchemy from examples/python
# and some examples/python fixes
# https://github.com/cossacklabs/acra/commit/34e162b335a3d2c248b8fd1e294c25bd5c78350e
RUN cd /root \
    && git clone https://github.com/cossacklabs/acra /root/acra \
    && cd /root/acra \
    && git checkout 34e162b335a3d2c248b8fd1e294c25bd5c78350e

RUN mkdir /app.requirements \
    && cp /root/acra/examples/python/requirements/* /app.requirements/
RUN pip3 install --no-cache-dir -r /app.requirements/postgresql.txt

RUN mkdir /app \
    && cp -r /root/acra/examples/python/* /app/

RUN echo -e '#!/bin/sh\n\nwhile true\ndo\n\tsleep 1\ndone\n' > /entry.sh
RUN chmod +x /entry.sh

VOLUME /app.acrakeys

RUN mkdir /ssl
COPY ssl/acra-client/acra-client.crt /ssl/acra-client.crt
COPY ssl/acra-client/acra-client.key /ssl/acra-client.key
COPY ssl/ca/ca.crt /ssl/root.crt

RUN chmod 0600 -R /ssl/


WORKDIR /app
ENTRYPOINT ["/entry.sh"]
