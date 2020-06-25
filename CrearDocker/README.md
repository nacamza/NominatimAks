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
Dentro de la imagen, se encuentran dos scripts .sh, uno sirve para crear la base de datos y el otro para implementar la aplicación. A continuación vamos a explicar lo más importante de cada uno.

### Generar la base de datos (init.sh)
El script init.sh es el encargado de generar la base de datos de nominatim, la misma se genera a partir de un archivo que se descarga de internet, en nuestro caso vamos a generar la base de datos para Argentina

El script genera la base de datos dentro del mismo docker, una vez generada, la copia a la carpeta **dataazure**. La carpeta **dataazure** no pertenece al docker, la misma de tiene montar cuando se genera el docker. 

Si se quiere generar la base de datos de otro país, se tiene que reemplazar la url de descarga en el script con la url deseada 
````
sudo curl http://download.geofabrik.de/south-america/argentina-latest.osm.pbf --output $OSMFILE
````
Una vez reemplazada la url en init.sh, tiene que generar nuevamente la imagen docker. Puede encontrar los países disponibles en la siguiente dirección http://download.geofabrik.de/
### Implementar nominatim (start.sh)
La implementación está pensada para funcionar con dos volúmenes montados
- Un volumen que suministra la base de datos que vamos a llamar **data**, este volumen es común para todos los pods. 
- Un volumen para utilizar la base de datos que vamos a llamar **bd**, este volumen es único para cada pod.
El script se inicia y se fija si en **bd** se encuentra la base de datos, de encontrarse inicia la aplicación normalmente. Si en **bd** no se encuentra la base de datos, el script la copia desde **data** y posteriormente inicia la aplicación.  





