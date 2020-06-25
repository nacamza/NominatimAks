# Instalar nominatim en AKS
Primero vamos a crear un nombre de espacio llamado nominatim en el cluster para la aplicación
````
kubectl create namespace nominatim
````
Tambien vamos a crear un nombre de espacio llamado ingress para el servidor de entrada, en nuestro caso vamos a usar un servidos nginx
````
kubectl create namespace ingress
````
Para ver los espacios de nombres en el clúster
````
kubectl get namespace
````
# Crear base de datos para nominatim
Para generar la base de datos aplique el siguiente archivo 
````
kubectl apply \
    --namespace nominatim \
    -f azurefile-bd-nominatim.yaml
````
En el archivo se configura un StorageClass llamado azurefile, la misma se utiliza para crear los archivos de almacenamiento azurefile. Ademas se declara un PersistentVolumeClaim que genera azurefile de 10Gb llamado **nominatim-bd-arg** donde vamos a guardar la base de datos.
Por ultimo generamos un Pod llamado nominatim-crear-bd que va a descargar la informacion de argentina y va a generar la base de datos.

Podemos revisar si el Pod fue generado con el siguiente comando
````
kubectl get pods --namespace nominatim
````
Si queremos entrar al pod usamos
````
kubectl exec -it nominatim-crear-bd --namespace nominatim -- /bin/bash
````
# Implementación de un controlador de entrada NGINX con Helm
Helm es un administrador de paquetes de aplicación para Kubernetes. Ofrece una manera fácil de implementar aplicaciones y servicios mediante gráficos.

El controlador de entrada de NGINX lo vamos a implementar com gráfico nginx-ingress de Helm. El gráfico helm de NGINX simplifica la configuración de implementación necesaria para el controlador de entrada.
Ejecute del siguiente comando helm repo add para configurar el cliente de Helm de forma que use el repositorio estable.
````
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
````
Después, instale el controlador de entrada de NGINX. Para obtener redundancia adicional, instalará dos réplicas de los controladores de entrada de NGINX implementadas con el parámetro --set controller.replicaCount.
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





# Crear la implementacion nominatim
Para crear la implementacion Nominatim aplique el siguiente archivo
````
kubectl apply \
    --namespace nominatim \
    -f nominatim-api-statefulset.yaml
````
En este archivo se realizan todos los cambios necesarios en el cluster para realizar la implementacion nominatim, a continuacion datallamos cada paso.
### Statefulset
Para la aplicacion nominatim vamos a utilizar una implementacion llamada Statefulset, este tipo de implementacion permite que cada pod de la aplicacion tenga un disco unico, esto es util ya que vamos a usar este disco para almacenar la base de datos de nominatim. 
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
        - name: azurefile
          persistentVolumeClaim:
            claimName: azurefile
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
            - name: azurefile
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
 




