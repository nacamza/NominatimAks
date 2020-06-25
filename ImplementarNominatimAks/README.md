# Instalar nominatim en AKS
Primero vamos a crear un nombre de espacio llamado **nominatim** en el cluster para la aplicación
````
kubectl create namespace nominatim
````
Tambien vamos a crear un nombre de espacio llamado **ingress** para el servidor de entrada, en nuestro caso vamos a usar un servidos nginx
````
kubectl create namespace ingress
````
Para ver los espacios de nombres en el clúster
````
kubectl get namespace
````
# Crear base de datos para nominatim
Para generar la base de datos aplique el siguiente archivo (tarda unas 7 horas en el caso de Argentina) 
````
kubectl apply \
    --namespace nominatim \
    -f nominatim-crear-bd.yaml
````
En el archivo se configura un StorageClass llamado azurefile, la misma se utiliza para crear archivos de almacenamiento azurefile. Ademas se declara un PersistentVolumeClaim que genera azurefile de 10Gb llamado **nominatim-bd-arg** donde vamos a guardar la base de datos.
Por ultimo generamos un Pod llamado nominatim-crear-bd que va a descargar la información de argentina y generar la base de datos.

Podemos revisar si el Pod fue generado con el siguiente comando
````
kubectl get pods --namespace nominatim
````
Si queremos entrar al pod usamos y ver si genero la base de datos usamos
````
kubectl exec -it nominatim-crear-bd --namespace nominatim -- /bin/bash
````
Una vez que se genera la base de datos se puede elininar el pod con el siguiente comando
````
kubectl delete pod nominatim-crear-bd --namespace nominatim
````
# Implementación de un controlador de entrada NGINX con Helm
Helm es un administrador de paquetes de aplicación para Kubernetes. Ofrece una manera fácil de implementar aplicaciones y servicios mediante gráficos.

Vamos a implementar com gráfico nginx-ingress con Helm.

Ejecute del siguiente comando ``helm repo add`` para configurar el cliente de Helm de forma que use el repositorio estable.
````
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
````
Después, instale el controlador de entrada de NGINX. Para obtener redundancia adicional, instalará dos réplicas de los controladores de entrada de NGINX implementadas con el parámetro ``--set controller.replicaCount``.
````
helm install nginx-ingress stable/nginx-ingress \
    --namespace ingress \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
````    
Ahora, se comprobará la IP pública del servicio de entrada. El servicio tarda unos minutos en adquirir la IP pública.
````
kubectl get service nginx-ingress-controller --namespace ingress -w
````
Guarde esta IP ya que la usaremos más adelante.
### Crear de un recurso de entrada para el servicio web de nominatim
#### Implementación de cert-manager
**Cert-manager** es un controlador de administración de certificados de Kubernetes que permite automatizar la administración de certificados en entornos nativos en la nube. cert-manager admite varios orígenes, entre los que se incluyen Let's Encrypt, HashiCorp Vault, Venafi, pares de clave de firma simples o certificados autofirmados.
Para empezar, se creará un espacio de nombres para cert-manager.
````
kubectl create namespace cert-manager
````
Usará el repositorio Jetstack de Helm para buscar e instalar cert-manager.
````
helm repo add jetstack https://charts.jetstack.io
helm repo update
````
Después, ejecute el siguiente comando para instalar cert-manager mediante la implementación del CRD de cert-manager.
````
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.14/deploy/manifests/00-crds.yaml
````
Instalación del gráfico Helm de cert-manager
````
helm install cert-manager \
    --namespace cert-manager \
    --version v0.14.0 \
    jetstack/cert-manager
````
Para comprobar la instalación, compruebe el espacio de nombres cert-manager para ejecutar pods.
````
kubectl get pods --namespace cert-manager
````
Verá que cert-manager, cert-manager-cainjector y el pod cert-manager-webhook están en un estado Running.
#### Implementación de un recurso ClusterIssuer para Let's Encrypt
Let's Encrypt es una entidad de certificación sin ánimo de lucro que proporciona certificados TLS. Let's Encrypt permite configurar un servidor HTTP y hacer que obtenga automáticamente un certificado de confianza del explorador. 
Edite el archivo cluster-issuer.yaml mediante el editor integrado.
````
nano cluster-issuer.yaml
````
Reemplace el contenido existente en el archivo por el texto siguiente.
````
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: <your email> # IMPORTANT: Replace with a valid email from your organization
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
````
Reemplace <your email> por un correo electrónico de administrador de certificados válido de la organización.

Aplique la configuración mediante el comando kubectl apply
````
kubectl apply \
    --namespace nominatim \
    -f cluster-issuer.yaml
````
#### Habilitación de SSL/TLS para el servicio web nominatim durante la entrada
Para que el controlador de entrada de Kubernetes enrute las solicitudes al servicio nominatim, necesitará un recurso de entrada que habilite SSL/TLS.

Edite el archivo nominatim-web-ingress.yaml.
````
nano nominatim-web-ingress.yaml
````
Pegue el siguiente texto en el archivo.
````
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: nominatim-web-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
    - hosts:
        - nominatim.<ingress ip>.nip.io 
      secretName: nominatim-web-cert
  rules:
    - host: nominatim.<ingress ip>.nip.io 
      http:
        paths:
          - backend:
              serviceName: nominatim
              servicePort: 80
            path: /
````
En este archivo, actualice el valor <ingress ip> de la clave host con la IP pública con guiones de la entrada que se ha recuperado antes    
    
Aplique la configuración mediante el comando kubectl apply
````
kubectl apply \
    --namespace nominatim \
    -f nominatim-web-ingress.yaml    
````
Compruebe que el certificado se haya emitido.
````
kubectl describe cert ratings-web-cert --namespace nominatim
````

# Crear la implementación nominatim
Para crear la implementación Nominatim aplique el siguiente archivo
````
kubectl apply \
    --namespace nominatim \
    -f nominatim-api-statefulset.yaml
````
En este archivo se realizan todos los cambios necesarios en el cluster para realizar la implementacion nominatim, a continuacion datallamos cada paso.
### Configuración de la aplicación para usar ClusterIP
Como la implementación se va a exponer mediante el servicio de entrada, no es necesario usar una IP pública para el servicio. 
````
apiVersion: v1
kind: Service
metadata:
  name: nominatim
spec:
  selector:
    app: nominatim
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
````
### Statefulset
Para la aplicación nominatim vamos a utilizar una implementación llamada Statefulset, este tipo de implementación permite que cada pod de la aplicación tenga un disco único, esto es util ya que vamos a usar este disco para almacenar la base de datos de nominatim. 
````
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nominatim
  namespace: nominatim
spec:  
  selector:
    matchLabels:
      app: nominatim
  serviceName: "nominatim"
  replicas: 1 
  template:
    metadata:
      labels:
        app: nominatim
    spec:
      terminationGracePeriodSeconds: 5
      volumes:
        - name: nominatim-bd-arg
          persistentVolumeClaim:
            claimName: nominatim-bd-arg
      containers:
        - name: nominatim
          image: cquirogaRegistry.azurecr.io/nominatim-arg
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
            - containerPort: 5432
          command: ["sh", "/app/start.sh"]
          volumeMounts:
            - name: volumen
              mountPath: /var/lib/postgresql/11/main
            - name: nominatim-bd-arg
              mountPath: /data
          resources:
            requests: # minimum resources required
              cpu: 250m
              memory: 64Mi
            limits: # maximum resources allocated
              cpu: 500m
              memory: 512Mi

  volumeClaimTemplates:
  - metadata:
      name: volumen
    spec:
      accessModes: 
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
```` 
La implementación utiliza la imagen **nominatim-arg** que esta almacenada en el contenedor **cquirogaRegistry**, ejecuta el script start.sh y monta dos volúmenes por cada pod. El volumen llamado **nominatim-bd-arg** es el que contiene la base de datos y el llamado **volumen** es el utilizado por cada pod para guardar la base de datos.

# Configurar el escalado automático
## Escalado automático horizontal
El controlador de escalador automático de pod horizontal (HPA) es un bucle de control de Kubernetes que permite al administrador de controladores de Kubernetes consultar el uso de recursos con las métricas especificadas en una definición de HorizontalPodAutoscaler.

El controlador HPA permite a AKS detectar cuándo los pods implementados necesitan más recursos en función de métricas como la CPU. Después, HPA puede programar más pods en el clúster para hacer frente a la demanda.

Edite el archivo nominatim-api-hpa.yaml
````
nano nominatim-api-hpa.yaml
````
El archivo tiene el siguiente contenido 
````
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: nominatim
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: nominatim
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 30
````
Dónde:
- Réplicas mínimas y máximas: Indica el número mínimo y máximo de réplicas que se van a implementar.
- Métricas: La métrica de escalado automático que se supervisa es el uso de CPU, establecido en un 30 %. Cuando el uso supera ese nivel, el HPA crea más réplicas.

Aplique el archivo
````
kubectl apply \
    --namespace nominatim \
    -f nominatim-api-hpa.yaml
````    
Para ver la carga de la implementación utilice el siguiente comando
````
kubectl get hpa \
  --namespace nominatim -w
````
## Escalado vertical 
Use el comando az aks update para habilitar el escalador automático del clúster. Especifique un valor máximo y otro mínimo para el número de nodos. Asegúrese de usar el mismo grupo de recursos anterior, por ejemplo aksworkshop.

En el ejemplo siguiente se establece --min-count en 1 y --max-count en 5.
````
az aks update \
--resource-group $RESOURCE_GROUP \
--name $AKS_CLUSTER_NAME  \
--enable-cluster-autoscaler \
--min-count 1 \
--max-count 5
````
En unos minutos, el clúster se debe configurar con el escalador automático del clúster.

Compruebe que el número de nodos ha aumentado.
````
kubectl get nodes -w
````
## Prueba de carga con el escalador automático
Para crear la prueba de carga, puede usar una imagen pregenerada llamada azch/artillery que está disponible en Docker Hub. La imagen contiene una herramienta llamada artillery que se usa para enviar tráfico a la API.

En Azure Cloud Shell, almacene el punto de conexión de la prueba de carga de la API de front-end en una variable de Bash y reemplace <frontend hostname> por el nombre de host de entrada expuesto
    
````
LOADTEST_API_ENDPOINT=https://nominatim.<ip cluster>.nip.io//search?q=mendoza&format=json&limit=1
````
Ejecute la prueba de carga con el siguiente comando 
````
az container create \
    -g $RESOURCE_GROUP \
    -n loadtest \
    --cpu 4 \
    --memory 1 \
    --image azch/artillery \
    --restart-policy Never \
    --command-line "artillery quick -r 500 -d 120 $LOADTEST_API_ENDPOINT"
````
Observe el funcionamiento del escalador automático horizontal de pod.
````
kubectl get hpa \
  --namespace nominatim -w
````






 




