# **BRIEF 11 - RAJA** 

1. **Creation groupe de resources:**

```consol
az group create --location westeurope --resource-group Brief11-Raja 
```

2. **Cree un cluster Aks** 
 
      ```consol
      - az aks create -g Brief11-Raja -n AKSCluster --generate-ssh-key --node-count 1 --enable-managed-identity -a ingress-appgw --appgw-name myApplicationGateway --appgw-subnet-cidr "10.225.0.0/16"   
      ```

3. **Ajouter le credentials**

    ```consol
    az aks get-credentials --name AKSCluster --resource-group Brief11-Raja
    ```

4. **Installer Traefik avec Helm Chart**

    ```consol
    helm install traefik traefik/traefik
    ```
    ![](https://hackmd.io/_uploads/HyvFdNxt3.png)

5. **Pour mettre a jours le repo**

    ```consol
    helm repo update
    ```
    **Pour lister le pod du helm**
    
    ```consol
    kubectl get pod
    ```

## **1/ Mettre en place une authentification BasicAuth HTTP avec mot de passe local defini dans la config de Traefik.**

### *vote.yml*

```consol 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: voteapp
  labels:
    app: voteapplb
spec:
  selector:
    matchLabels:
      app: voteapplb
  replicas: 1
  template:
    metadata:
      labels:
        app: voteapplb
    spec:
      containers:
      - name: voteapp
        image: raja8/vote-app:1.0.111
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "150m"
            memory: "100Mi"
        env:
        - name: REDIS
          value: "clustredis"
        - name: STRESS_SECS
          value: "2"
        - name: REDIS_PWD
          valueFrom:
            secretKeyRef:
              name: redispw
              key: password
```
### *service.yml*

```consol

apiVersion: v1
kind: Service
metadata:
  name: loadvoteapp 
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: voteapplb

```

### *redis.yml*

```consol

apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redislb
spec:
  selector:
    matchLabels:
      app: redislb
  replicas: 1
  template:
    metadata:
      labels:
        app: redislb
    spec:
      volumes: 
      - name: vol
        persistentVolumeClaim:
          claimName: redisclaim
      containers:
      - name: redis
        image: redis
        args: ["--requirepass", "$(REDIS_PWD)"]
        env:
        - name: REDIS_PWD
          valueFrom:
            secretKeyRef:
              name: redispw
              key: password
        - name: ALLOW_EMPTY_PASSWORD
          value: "no"
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:
        - name: vol
          mountPath: "/data"

```
### *service.yml*

```consol

apiVersion: v1
kind: Service
metadata:
  name: clustredis
spec:
  type: ClusterIP
  ports:
  - port: 6379
  selector:
    app: redislb
```
### *storageclass.yml*

```consol

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: redisstor
provisioner: kubernetes.io/azure-disk
parameters: 
  skuName: Standard_LRS
allowVolumeExpansion: true

```

### *pvc.yml*

```consol

apiVersion: v1
kind: PersistentVolumeClaim
metadata: 
  name: redisclaim
spec:    
  accessModes:
    - ReadWriteOnce
  resources: 
    requests:
      storage: 10Gi
  storageClassName: redisstor
```

### *ingress.yml*

```consol 

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-vote
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd
spec:
  rules:
  - host: vote.simplon-raja.space
    http:
      paths:
      - pathType: ImplementationSpecific
        path: /
        backend:
          service:
            name: loadvoteapp
            port:
              number: 80
    
```

### *traefik.yml*

```consol

apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basicauth
spec:
  basicAuth:
    secret: authsecret
    removeHeader: false

```

apiVersion: v1
kind: Secret
metadata:
  name: redispw
type: Opaque
data:  
  password: YnJpZWY3cmFqYQ==

---

apiVersion: v1
kind: Secret
metadata:
  name: authsecret
data:
  users: cmFqYTokYXByMSRvS2JBV2tQTyRTSG5aT2ZEWHFwLkpUU2VDemJQL1guCgo=

- Pour chiffré le MDP 

```consol
htpasswd -nb user password | openssl base64
htpasswd -nb user password | openssl base64
```

- **Deployment redis, vote et traefik**

    ![](https://hackmd.io/_uploads/Bkq7cNlFh.png)

- Pour se connecter à l'app vote --> http://20.76.188.65

    ![](https://hackmd.io/_uploads/B1t0NSgF2.png)

![](https://hackmd.io/_uploads/SJIKEtWYn.png)


## 2/ Mettre en place un filtrage d’adresse IP sur Traefik.

## **kubectl patch svc traefik -p '{"spec":{"externalTrafficPolicy":"Local"}}' -n default**


```consol

apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: ipwhitelist
spec:
  ipWhiteList:
    sourceRange:
      - 81.64.168.221 
```

- 81.64.168.221 -> mon addresse IPv4

### *traefik.yml*

```consol
kubectl patch svc traefik -p '{"spec":{"externalTrafficPolicy":"Local"}}' -n default
```
Test avec le partage de connection

![](https://hackmd.io/_uploads/S1waVsWFh.png)

## **3/ Mettre en place un certificat TLS sur Traefik qui doit etre lie a votre domaine. Utiliser Let’s Encrypt pour cela. Les acces HTTP doivent etre interdits et/ou rediriges en HTTPS.**

1.  *Installer Cert-manager*

```consol
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
```
Cert-manager est un contrôleur Kubernetes open-source qui automatise la gestion des certificats TLS (Transport Layer Security) pour les applications s'exécutant dans un cluster Kubernetes. Il facilite la demande, l'émission et le renouvellement des certificats SSL/TLS en intégrant des fournisseurs de certificats tels que Let's Encrypt.

### *tls.yml*

```consol

apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect
  namespace: default

spec:
  redirectScheme:
    scheme: https
    permanent: true

```
### *ingress.yml*

```consol

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-vote
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd,default-ipwhitelist@kubernetescrd,default-redirect@kubernetescrd
spec:
  rules:
  - host: vote.simplon-raja.space
    http:
      paths:
      - pathType: ImplementationSpecific
        path: /
        backend:
          service:
            name: loadvoteapp
            port:
              number: 80

```
