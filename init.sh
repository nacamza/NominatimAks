
sudo curl http://download.geofabrik.de/south-america/argentina-latest.osm.pbf --output /data/argentina-latest.osm.pbf
chown postgres:postgres /data && \

export  PGDATA=/data  && \
sudo -u postgres /usr/lib/postgresql/11/bin/initdb -D /data && \
sudo -u postgres /usr/lib/postgresql/11/bin/pg_ctl -D /data start && \
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim && \
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data && \
sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim" && \
useradd -m -p password1234 nominatim && \
chown -R nominatim:nominatim ./src && \
sudo -u nominatim ./src/build/utils/setup.php --osm-file argentina-latest.osm.pbf --all --threads 4 && \
sudo -u postgres /usr/lib/postgresql/11/bin/pg_ctl -D /data stop && \
sudo chown -R postgres:postgres /data
