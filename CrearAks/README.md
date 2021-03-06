## Implementación de Kubernetes con Azure Kubernetes Service
Este instructivo está basado en un taller de azure, si necesita más información puede buscarla en https://docs.microsoft.com/es-es/learn/modules/aks-workshop/01-introduction
### Vamos a definir las siguientes variables de estado
Estas variables van a facilitar la implementación 
````
REGION_NAME=eastus
RESOURCE_GROUP=aksworkshop
VNET_NAME=aks-vnet
SUBNET_NAME=aks-subnet
AKS_CLUSTER_NAME=aksworkshop-nominatim
ACR_NAME=cquirogaRegistry
````
Dónde:
-	REGION_NAME: es la región donde se va a crear al clúster
-	RESOURCE_GROUP: es el grupo de recursos donde se va a crear el clúster
-	VNET_NAME: es la red virtual a la que está conectada el clúster
-	SUBNET_NAME:  es la subred del clúster 
-	AKS_CLUSTER_NAME: Nombre del clúster AKS 
-   ACR_NAME: Nomber del registro de contenedores
## Crear grupo de recursos 
Vamos a crear un grupo de recursos en donde vamos a crear el cluster, con el nombre **aksworkshop** alojado en la región  ** eastus**
````
az group create \
    --name $RESOURCE_GROUP \
    --location $REGION_NAME
````
## Crear red para el clúster
En primer lugar, vamos a crear una red virtual y una subred. A los pods que se implementan en el clúster se les asignará una dirección IP de esta subred.
````
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --location $REGION_NAME \
    --name $VNET_NAME \
    --address-prefixes 10.0.0.0/8 \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix 10.240.0.0/16
```` 
Después, recupere y almacene el id. de subred en una variable de Bash mediante la ejecución del siguiente comando 
````
SUBNET_ID=$(az network vnet subnet show \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $SUBNET_NAME \
    --query id -o tsv)
````
## Creación del clúster de AKS
Para obtener la versión más reciente de Kubernetes, use el comando az aks get-versions
````
VERSION=$(az aks get-versions \
    --location $REGION_NAME \
    --query 'orchestrators[?!isPreview] | [-1].orchestratorVersion' \
    --output tsv)
````
Ahora si creamos el clúster 
````
az aks create \
--resource-group $RESOURCE_GROUP \
--name $AKS_CLUSTER_NAME \
--vm-set-type VirtualMachineScaleSets \
--load-balancer-sku standard \
--location $REGION_NAME \
--kubernetes-version $VERSION \
--network-plugin azure \
--vnet-subnet-id $SUBNET_ID \
--service-cidr 10.2.0.0/24 \
--dns-service-ip 10.2.0.10 \
--docker-bridge-address 172.17.0.1/16 \
--generate-ssh-keys
````
Vamos a revisar las variables en el comando anterior:
-	$AKS_CLUSTER_NAME especifica el nombre del clúster de AKS.
-	$VERSION es la versión más reciente de Kubernetes que se ha recuperado antes.
-	$SUBNET_ID es el id. de la subred creada en la red virtual que se va a configurar con AKS.

Tenga en cuenta la siguiente configuración de implementación:

-	--vm-set-type: se especifica que el clúster se crea mediante conjuntos de escalado de máquinas virtuales. Los conjuntos de escalado de máquinas virtuales permiten cambiar al escalador automático de clúster cuando sea necesario.
-	--network-plugin: se especifica la creación del clúster de AKS mediante el complemento CNI.
-	--service-cidr: este intervalo de direcciones es el conjunto de direcciones IP virtuales que Kubernetes asigna a los servicios internos del clúster. No debe estar dentro del intervalo de direcciones IP de la red virtual del clúster. Debe ser diferente de la subred creada para los pods.
-	--dns-service-ip: la dirección IP es para el servicio DNS del clúster. Esta dirección debe estar en el intervalo de direcciones del servicio de Kubernetes. No use la primera dirección IP en el intervalo de direcciones, como 0.1. La primera dirección del rango de la subred se usa para la dirección kubernetes.default.svc.cluster.local.
-	--docker-bridge-address: la dirección de red del puente de Docker representa la dirección de red de puente docker0 predeterminada presente en todas las instalaciones de Docker. 
## Prueba de la conectividad del clúster con kubectl
Para recuperar las credenciales del clúster, ejecute el comando siguiente
````
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME
````
Para ver los nodos del cluster use 
````
kubectl get nodes
````
## Creación de un registro de contenedor
Si no tiene un registro de contenedores tiene que crear uno
````
az acr create \
    --resource-group $RESOURCE_GROUP \
    --location $REGION_NAME \
    --name $ACR_NAME \
    --sku Standard
````
## Configuración del clúster de AKS para autenticarse en el registro de contenedor
Es necesario configurar la autenticación entre el registro de contenedor y el clúster de Kubernetes para permitir la comunicación entre los servicios. Puede configurar de forma automática la autenticación de la entidad de servicio necesaria entre los dos recursos si ejecuta el comando az aks update
````
az aks update \
    --name $AKS_CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --attach-acr $ACR_NAME
```` 






