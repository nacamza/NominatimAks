## Instalar nominatim en AKS
Primero vamos a crear un nombre de espacio llamado nominatim en el cluster para la aplicación
````
kubectl create namespace naminatim
````
Para ver los espacios de nombres en el clúster
````
kubectl get namespace
````
### Crear base de datos para nominatim
Primero vamos a crear la base de datos nesesaria para la aplicacion. La misma la vamos a almacenar en un AzureFile.
Para crear el AzureFile en el cluster aplicamos el siguiente archivo
````
kubectl apply \
    --namespace nominatim \
    -f azurefile-bd-nominatim.yaml
````
En el archivo se configura una StorageClass llama azurefile, la misma se utiliza para crear los archivos de almacenamiento. Tambien se declara un PersistentVolumeClaim que genera azurefile de 10Gb llamado azurefile donde vamos a gurdar la base de datos



### Crear la implementacion naminatim
Para la implementacion vamos a utilizar la implementacion llamada Statefulset ya que nos permite asignar un disco a cada pod, es este disco vamos a almacenar la base de datos de nominatim
