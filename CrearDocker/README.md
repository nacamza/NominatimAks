## Crear imagen Nominatim Docker (Nominatim version 3.4)
### Crear imagen Nominatim
Vamos a generar una imagen de nominatim en Azure Container Registry, para esto, generamos las siguientes variables de entorno
````
REGION_NAME=eastus
RESOURCE_GROUP=myResourceGroup
ACR_NAME=cquirogaRegistry
````
Ahora podemos construir la imagen
````
az acr build \
    --resource-group $RESOURCE_GROUP \
    --registry $ACR_NAME \
    --image nominatim-arg .
````
### Comprobación de las imágenes
Ejecute el comando siguiente para comprobar que las imágenes se han creado y almacenado en el registro
````
az acr repository list \
    --name $ACR_NAME \
    --output table
````
Si todo salió bien, tiene que aparecer una imagen llamada nominatim-arg.
## Docker nominatim
Dentro de las imagen se encuentrar dos scripts sh, uno sirve para crear la base de datos y el otro para implementar la aplicacion, vamos a explicar lo importente de cada uno

### Generar la base de datos (init.sh)
El scrit init.sh es el encargado de generar la base de datos de nominatim, la misma se genera a partir de un archibo que se descarga de internet, en nuestro caso vamos a generar la base de datos para Argentina

El scrip genera la base de datos dentro del mismo docker, una vez generada la copia a la carpeta **dataazure**, esta carpeta no pertenece al docker. 

Si se quiere generar la base de datos de otro pais, se tiene que reemplazar la url de descarga en el escrip con la url deseada 
````
sudo curl http://download.geofabrik.de/south-america/argentina-latest.osm.pbf --output $OSMFILE
````
Una vez reemplazada la url en init.sh, tiene que generar nuevamente la imagen docker 



