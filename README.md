# Intro

This demo discovers some of many possible variants of building HA and balanced
infrastructure, based on Acra components, PostgreSQL and AcraPythonDemo. In our
examples, as a balancer, we used HAProxy - one of the most popular proxies
today.

These stands was created only for demonstration purposes and structure of
examples was intentionally simplified, HAProxy configuration is optimized
NOT for performance, but for clarity of tests.

---

# Stand : `docker-compose.acra-haproxy-pgsql.yml`

## Scheme

```
╭─────────────────╮ ╭─────────────────╮
│ pgsql-master    ├─┤ pgsql-slave     │
╰────────┬────────╯ ╰────────┬────────╯
         ╰─────────┬─────────╯
          ╭────────┴────────╮
          │ haproxy         │
          ╰────────┬────────╯
          ╭────────┴────────╮
          │ acra-server     │
          ╰────────┬────────╯
          ╭────────┴────────╮
          │ acra-connector  │
          ╰────────┬────────╯
         ╭─────────┴─────────╮
╭────────┴────────╮ ╭────────┴────────╮
│ python-example  │ │ acra-webconfig  │
╰─────────────────╯ ╰─────────────────╯
```

## World accessible resources

* `pgsql-master`
  - tcp/5434 : postgresql (user: postgres, password: test, db: test)
  - tcp/9001 : http healtcheck
* `pgsql-slave`
  - tcp/5435 : postgresql (user: postgres, password: test, db: test)
  - tcp/9002 : http healtcheck
* `haproxy`
  - tcp/5432 : RW access to postgresql cluster
  - tcp/5433 : RO access to postgresql cluster
* `acra-connector`
  - tcp/9494 : acra-connector
* `acra-webconfig`
  - tcp/8000 : acra-webconfig (user: test, password: test)


## Start & Stop

```bash
# Start
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml up

# Stop, clean built images, remove keys
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml down; \
    docker image prune --all --force \
    --filter "label=com.cossacklabs.product.name=acra-haproxy-pgsql"; \
    rm -rf ./.acra{keys,configs}
# Stop only and do not clean built images
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml down
```

## Tests

### Simple SQL query

```bash
# Trying to write
psql postgres://postgres:test@localhost:9494/postgres?sslmode=disable <<'EOSQL'
CREATE DATABASE "TEST" WITH OWNER="postgres" TEMPLATE=template0 ENCODING='UTF-8';
EOSQL
# CREATE DATABASE

psql postgres://postgres:test@localhost:9494/postgres?sslmode=disable
# postgres=# \l
#                                  List of databases
#    Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
# -----------+----------+----------+------------+------------+-----------------------
#  TEST      | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
```

### Python without zones

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Write data:
docker exec -it $DOCKER_PYTHON \
    python /app/example_without_zone.py --data="some data #1"
# insert data: some data #1

# Read data:
docker exec -it $DOCKER_PYTHON python /app/example_without_zone.py --print
# id  - data                 - raw_data
# 1   - some data #1         - some data #1
```

### Python with zones

Before testing with zones, open AcraWebConfig and enable zone mode.

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Write data:
docker exec -it $DOCKER_PYTHON \
    python /app/example_with_zone.py --data="some data"
# data: some data
# zone: DDDDDDDDjzaErohiNAaYhChb

# Read data:
ZONE_ID=DDDDDDDDjzaErohiNAaYhChb
docker exec -it $DOCKER_PYTHON \
    python /app/example_with_zone.py --print --zone_id=$ZONE_ID
# use zone_id:  DDDDDDDDjzaErohiNAaYhChb
# id  - zone - data - raw_data
# 1   - DDDDDDDDjzaErohiNAaYhChb - some data - some data
```

---

# Stand : `docker-compose.haproxy-acra-pgsql[_zonemode].yml`

## Scheme

```
╭───────────────────╮ ╭───────────────────╮
│ pgsql-master      ├─┤ pgsql-slave       │
╰─────────┬─────────╯ ╰─────────┬─────────╯
╭─────────┴─────────╮ ╭─────────┴─────────╮
│ acra-server-m     │ │ acra-server-s     │
╰─────────┬─────────╯ ╰─────────┬─────────╯
          ╰──────────┬──────────╯
           ╭─────────┴─────────╮
           │ haproxy           │
           ╰─────────┬─────────╯
          ╭──────────┴──────────╮
╭─────────┴─────────╮ ╭─────────┴─────────╮
│ acra-connector-rw │ │ acra-connector-ro │
╰─────────┬─────────╯ ╰─────────┬─────────╯
          ╰──────────┬──────────╯
           ╭─────────┴─────────╮
           │ python-example    │
           ╰───────────────────╯
```

## World accessible resources

* `pgsql-master`
  - tcp/5434 : postgresql (user: postgres, password: test, db: test)
  - tcp/9001 : http healtcheck
* `pgsql-slave`
  - tcp/5435 : postgresql (user: postgres, password: test, db: test)
  - tcp/9002 : http healtcheck
* `haproxy`
  - tcp/9393 : RW access to postgresql cluster through acra-server
  - tcp/9394 : RO access to postgresql cluster through acra-server
* `acra-connector`
  - tcp/9494 : acra-connector-rw
  - tcp/9495 : acra-connector-ro


## Tests

In this examples we have multiple running AcraServers and HAProxy that balancing
connections from AcraConnector. It is currently unsupported to manage multiple
AcraServers through AcraWebConfig in that model and switch between modes
`with zones` and `without zones` on the fly.

So you have to run two different docker-compose configurations for next two
examples.


### Python without zones

#### Start & Stop

```bash
# Start
docker-compose -f ./docker-compose.haproxy-acra-pgsql.yml up

# Stop, clean built images, remove keys
docker-compose -f ./docker-compose.haproxy-acra-pgsql.yml down; \
    docker image prune --all --force \
    --filter "label=com.cossacklabs.product.name=acra-haproxy-pgsql"; \
    rm -rf ./.acra{keys,configs}
# Stop only and do not clean built images
docker-compose -f ./docker-compose.haproxy-acra-pgsql.yml down
```

#### Run test

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Write through RW chain: acra-connector-rw -> haproxy -> pgsql-master
docker exec -it $DOCKER_PYTHON \
    python /app/example_without_zone.py --data="some data #1"
# insert data: some data #1

# Read from RO chain: acra-connector-ro <- haproxy <- pgsql-(master|slave)
docker exec -it $DOCKER_PYTHON \
    python /app/example_without_zone.py --host acra-connector-ro --print
# id  - data                 - raw_data
# 1   - some data #1         - some data #1
```

### Python with zones

#### Start & Stop

```bash
# Start
docker-compose -f ./docker-compose.haproxy-acra-pgsql_zonemode.yml up

# Stop, clean built images, remove keys
docker-compose -f ./docker-compose.haproxy-acra-pgsql_zonemode.yml down; \
    docker image prune --all --force \
    --filter "label=com.cossacklabs.product.name=acra-haproxy-pgsql"; \
    rm -rf ./.acra{keys,configs}
# Stop only and do not clean built images
docker-compose -f ./docker-compose.haproxy-acra-pgsql_zonemode.yml down
```

#### Run test

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Write through RW chain: acra-connector-rw -> haproxy -> pgsql-master
docker exec -it $DOCKER_PYTHON \
    python /app/example_with_zone.py --data="some data"
# data: some data
# zone: DDDDDDDDjzaErohiNAaYhChb

# Read from RO chain: acra-connector-ro <- haproxy <- pgsql-(master|slave)
ZONE_ID='DDDDDDDDjzaErohiNAaYhChb'
docker exec -it $DOCKER_PYTHON \
    python /app/example_with_zone.py \
    --host acra-connector-ro --print --zone_id=$ZONE_ID
# use zone_id:  DDDDDDDDjzaErohiNAaYhChb
# id  - zone - data - raw_data
# 1   - DDDDDDDDjzaErohiNAaYhChb - some data - some data
```
