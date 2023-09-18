# What is this?

Learn how to build high availability and balanced infrastructures for AcraServer based on HAProxy.

This demo illustrates some of the many possible variants of building high availability and balanced
infrastructures, based on [Acra data protection suite](https://cossacklabs.com/acra/) components, PostgreSQL, and Python application protected by Acra. In these examples, we used [HAProxy](http://www.haproxy.org/) – one of the most popular high availability balancers today.

This project is one of numerous Acra's example applications. If you are curious about other Acra features, like transparent encryption, SQL firewall, load balancing support – [Acra Example Applications](https://github.com/cossacklabs/acra-engineering-demo/).

These stands were created only for demonstration purposes and structure of examples was intentionally simplified, HAProxy configuration is optimized NOT for performance, but for clarity of tests.

This demo has two examples:

| [One Acra Server, two databases](https://github.com/cossacklabs/acra-balancer-demo#stand--docker-composeacra-haproxy-pgsqlyml) | [Two Acra Servers, two databases](https://github.com/cossacklabs/acra-balancer-demo#stand--docker-composehaproxy-acra-pgsql_zonemodeyml) |
|--------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|

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
          │ python-example  │
          ╰─────────────────╯
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


## Start & Stop

```bash
# Start
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml up --build

# Stop, clean built images, remove keys
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml down; \
    docker image prune --all --force \
    --filter "label=com.cossacklabs.product.name=acra-haproxy-pgsql"; \
    rm -rf ./.acra{keys,configs}
# Stop only and do not clean built images
docker-compose -f ./docker-compose.acra-haproxy-pgsql.yml down -v
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

### Python

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Write data:
docker exec -it $DOCKER_PYTHON \
    python /app/example.py --data="some data #1"
# insert data: some data #1

# Read data:
docker exec -it $DOCKER_PYTHON python /app/example.py --print
# id  - data                 - raw_data
# 1   - some data #1         - some data #1
```

---

# Stand : `docker-compose.haproxy-acra-pgsql.yml`

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


## Tests

In these examples we have multiple running AcraServers and HAProxy that balancing
connections from Python.

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
docker-compose -f ./docker-compose.haproxy-acra-pgsql.yml down -v
```

#### Run test

```bash
# Get the name of the python container
DOCKER_PYTHON=$(docker ps \
    --filter "label=com.cossacklabs.product.component=acra-python-example" \
    --format "{{.Names}}") || echo 'Can not find container!'

# Write through RW chain:  haproxy -> acra-server-(m|s) -> pgsql-(master|slave)
docker exec -it $DOCKER_PYTHON \
    python /app/example.py --data="some data #1"
# insert data: some data #1

# Read from RO chain:  haproxy <- acra-server-(m|s) <- pgsql-(master|slave)
docker exec -it $DOCKER_PYTHON \
    python /app/example.py --host acra-server-s --print
# id  - data                 - raw_data
# 1   - some data #1         - some data #1
```

# Further steps

Let us know if you have any questions by dropping an email to [dev@cossacklabs.com](mailto:dev@cossacklabs.com).

1. [Acra features](https://cossacklabs.com/acra/) – check out full features set and available licenses.
2. Other [Acra example applications](https://github.com/cossacklabs/acra-engineering-demo/) – try other Acra features, like transparent encryption, SQL firewall, load balancing support.

# Need help?

Need help in configuring Acra? Our support is available for [Acra Pro and Acra Enterprise versions](https://www.cossacklabs.com/acra/#pricing).
