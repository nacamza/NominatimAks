## Crear imagen Nominatim Docker (Nominatim version 3.4)
### Crear imagen Nominatim
Para crear la imagen clonamos el siguiente repocitorio
````
git clone https://github.com/nacamza/NominatimAks.git
````
Luego vamos a la carpeta llamada CrearDocker 
````
cd CrearDocker
````
Vamos a generar la imagen en Azure Container Registry, para esto, generamos las siguientes variables de entorno
````
REGION_NAME=eastus
RESOURCE_GROUP=myResourceGroup
VNET_NAME=aks-vnet
SUBNET_NAME=aks-subnet
AKS_CLUSTER_NAME=aksworkshop-nominatim
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
Si todo salió bien, tiene que aparecer una imagen llamada nominatim-arg
