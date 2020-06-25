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
### Crear de un recurso de entrada para el servicio web de nominatim
#### Implementación de cert-manager
cert-manager es un controlador de administración de certificados de Kubernetes que permite automatizar la administración de certificados en entornos nativos en la nube. cert-manager admite varios orígenes, entre los que se incluyen Let's Encrypt, HashiCorp Vault, Venafi, pares de clave de firma simples o certificados autofirmados.
Para empezar, se creará un espacio de nombres para cert-manager.
````
kubectl create namespace cert-manager
````
Usará el repositorio Jetstack de Helm para buscar e instalar cert-manager.
````
helm repo add jetstack https://charts.jetstack.io
helm repo update
````
Después, ejecute el comando siguiente para instalar cert-manager mediante la implementación del CRD de cert-manager.
````
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.14/deploy/manifests/00-crds.yaml
````
Instalación del gráfico Helm de cert-manager
´´´´
helm install cert-manager \
    --namespace cert-manager \
    --version v0.14.0 \
    jetstack/cert-manager
´´´´
Para comprobar la instalación, compruebe el espacio de nombres cert-manager para ejecutar pods.
````
kubectl get pods --namespace cert-manager
````
Verá que cert-manager, cert-manager-cainjector y el pod cert-manager-webhook están en un estado Running.
#### Implementación de un recurso ClusterIssuer para Let's Encrypt
Let's Encrypt es una entidad de certificación sin ánimo de lucro que proporciona certificados TLS. Let's Encrypt permite configurar un servidor HTTP y hacer que obtenga automáticamente un certificado de confianza del explorador. 
Edite el archivo cluster-issuer.yaml mediante el editor integrado.
````
code cluster-issuer.yaml
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
En la clave email, para actualizar el valor, reemplace <your email> por un correo electrónico de administrador de certificados válido de la organización.

Aplique la configuración mediante el comando kubectl apply
````
kubectl apply \
    --namespace ratingsapp \
    -f cluster-issuer.yaml
````
#### Habilitación de SSL/TLS para el servicio web nominatim durante la entrada
Para que el controlador de entrada de Kubernetes enrute las solicitudes al servicio nominatim, necesitará un recurso de entrada que habilite SSL/TLS.

Edite el archivo nominatim-web-ingress.yaml mediante el editor integrado.
´´´´
nano nominatim-web-ingress.yaml
´´´´
Pegue el texto siguiente en el archivo.
´´´´
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
      secretName: ratings-web-cert
  rules:
    - host: nominatim.<ingress ip>.nip.io 
      http:
        paths:
          - backend:
              serviceName: nominatim
              servicePort: 80
            path: /
´´´´
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

# Crear la implementacion nominatim
Para crear la implementacion Nominatim aplique el siguiente archivo
````
kubectl apply \
    --namespace nominatim \
    -f nominatim-api-statefulset.yaml
````
En este archivo se realizan todos los cambios necesarios en el cluster para realizar la implementacion nominatim, a continuacion datallamos cada paso.
### Confiuracion de la aplicacion para usar ClusterIP
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
 




