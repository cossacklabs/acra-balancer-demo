
#===== Stand : docker-compose.acra-haproxy-pgsql.yml ===========================

# Scheme

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

# World accessible resources

* `pgsql-master`
  - tcp/5434 : postgresql
  - tcp/9001 : http healtcheck
* `pgsql-slave`
  - tcp/5435 : postgresql
  - tcp/9002 : http healtcheck
* `haproxy`
  - tcp/5432 : RW access to postgresql cluster
  - tcp/5433 : RO access to postgresql cluster
* `acra-connector`
  - tcp/9494 : acra-connector
* `acra-webconfig`
  - tcp/8000 : acra-webconfig


# Start & Stop

```bash
# Start
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml up

# Stop and clean built images
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml down; \
    docker image prune --all --force \
    --filter "label=com.cossacklabs.product.name=acra-haproxy-pgsql"
# Stop only and do not clean built images
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml down
```

# Tests

## Simple SQL query

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

## Python without zones

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Run example without zones (write, read):
docker exec -it $DOCKER_PYTHON \
    python /app/example_without_zone.py --data="some data #1"
# insert data: some data #1

docker exec -it $DOCKER_PYTHON python /app/example_without_zone.py --print
# id  - data                 - raw_data
# 1   - some data #1         - some data #1
```

## Python with zones

```bash
# Before testing with zones, open AcraWebConfig and enable zone mode.

# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Run example with zones (write, read):
docker exec -it $DOCKER_PYTHON python /app/example_with_zone.py --data="some data"
docker exec -it $DOCKER_PYTHON \
    python /app/example_with_zone.py --print --zone_id=$ZONE_ID
# where $ZONE_ID - zone id, printed on write step
```
