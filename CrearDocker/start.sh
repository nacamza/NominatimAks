#!/bin/bash

stopServices() {
        service apache2 stop
        service postgresql stop
}
trap stopServices TERM

if [ -f /var/lib/postgresql/11/main/PG_VERSION ];
then
        echo "La BD existe"
else
        echo "La BD no existe"
        cp -r /bd/postgresdata/* /var/lib/postgresql/11/main
        chown -R postgres:postgres /var/lib/postgresql/11/main
        chmod -R 700 /var/lib/postgresql/11/main
        echo "BD copiada"
fi

service postgresql start
service apache2 start

# fork a process and wait for it
tail -f /var/log/postgresql/postgresql-11-main.log &
wait