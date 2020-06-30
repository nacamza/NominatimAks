OSMFILE=/data/argentina-latest.osm.pbf
PGDIR=postgresdata
THREADS=1

stopServices() {
        service apache2 stop
        service postgresql stop
}
trap stopServices TERM

echo "Descargo mapa Arg"
sudo curl http://download.geofabrik.de/south-america/argentina-latest.osm.pbf --output $OSMFILE
#sudo curl http://download.geofabrik.de/asia/maldives-latest.osm.pbf --output $OSMFILE

rm -rf /data/$PGDIR && \
mkdir -p /data/$PGDIR && \

chown postgres:postgres /data/$PGDIR && \

echo "Inicio generar bd"
export  PGDATA=/data/$PGDIR  && \
sudo -u postgres /usr/lib/postgresql/11/bin/initdb -D /data/$PGDIR && \
sudo -u postgres /usr/lib/postgresql/11/bin/pg_ctl -D /data/$PGDIR start && \
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim && \
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data && \
sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim" && \
useradd -m -p password1234 nominatim && \
chown -R nominatim:nominatim ./src && \
sudo -u nominatim ./src/build/utils/setup.php --osm-file $OSMFILE --all --threads $THREADS && \
sudo -u postgres /usr/lib/postgresql/11/bin/pg_ctl -D /data/$PGDIR stop && \
sudo chown -R postgres:postgres /data/$PGDIR

echo "Bd generada"

cp -r /data/* /dataazure
rm -r /data/*

echo "Bd copiada" 

echo "Listo" 

service postgresql start
service apache2 start

# fork a process and wait for it
tail -f /var/log/postgresql/postgresql-11-main.log &
wait
