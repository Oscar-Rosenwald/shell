#!/bin/bash
#
# Run an instance of postgres separately for testing modules that require access
#

docker run --rm --network="host" --tmpfs /var/lib/postgresql/data:rw,noexec,nosuid,size=1G -v $HOME/Data/postgresql.conf:/etc/postgresql/postgresql.conf -e POSTGRES_PASSWORD=pass --name postgrestest db:latest -c 'config_file=/etc/postgresql/postgresql.conf' 2>&1 | tee postgres.txt
