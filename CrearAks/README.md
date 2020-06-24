## Implementación de Kubernetes con Azure Kubernetes Service
### Vamos a definir las siguientes variables de estado
````
REGION_NAME=eastus
RESOURCE_GROUP=aksworkshop
VNET_NAME=aks-vnet
SUBNET_NAME=aks-subnet
AKS_CLUSTER_NAME=aksworkshop-nominatim
````
Dónde:
-	REGION_NAME es la región donde se va a crear al clúster
-	RESOURCE_GROUP es el grupo de recursos donde se va a crear el clúster
-	VNET_NAME es la red virtual a la que está conectada el clúster
-	SUBNET_NAME  es la subred del clúster 
-	AKS_CLUSTER_NAME Nombre del clúster AKS 
## Crear grupo de recursos 
Vamos a crear un grupo de recursos con el nombre **aksworkshop** alojado en la región  ** eastus**
````
az group create \
    --name $RESOURCE_GROUP \
    --location $REGION_NAME
````
## Crear red para el clúster
En primer lugar, cree una red virtual y una subred. A los pods que se implementan en el clúster se les asignará una dirección IP de esta subred.
````
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --location $REGION_NAME \
    --name $VNET_NAME \
    --address-prefixes 10.0.0.0/8 \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix 10.240.0.0/16
```` 
Después, recupere y almacene el id. de subred en una variable de Bash mediante la ejecución del comando siguiente
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
-	--docker-bridge-address: la dirección de red del puente de Docker representa la dirección de red de puente docker0 predeterminada presente en todas las instalaciones de Docker. Los clústeres de AKS o los propios pods no usan el puente docker0. Pero tendrá que establecer esta dirección para seguir admitiendo escenarios como docker build en el clúster de AKS. Es necesario seleccionar un enrutamiento de interdominios sin clases (CIDR) para la dirección de red del puente de Docker. Si no establece un CIDR, Docker elige una subred automáticamente. Esta subred podría entrar en conflicto con otros CIDR. Elija un espacio de direcciones que no entre en conflicto con el resto de los CIDR de las redes, incluidos el del servicio del clúster y el del pod.
