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

```consol

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

# **2/ Mettre en place un filtrage d’adresse IP sur Traefik.**

### *ip.yml*

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

```consol
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-vote
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd,default-ipwhitelist@kubernetescrd
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

```consol
kubectl patch svc traefik -p '{"spec":{"externalTrafficPolicy":"Local"}}' -n default
```

La commande "kubectl patch" avec le patch spécifié modifie la politique de trafic externe du service "traefik" dans l'espace de noms "default" afin de router le trafic uniquement vers les pods sur le nœud où le trafic arrive.


* Test avec le partage de connection 
![](https://hackmd.io/_uploads/S1waVsWFh.png)


## **3/ Mettre en place un certificat TLS sur Traefik qui doit etre lie a votre domaine. Utiliser Let’s Encrypt pour cela. Les acces HTTP doivent etre interdits et/ou rediriges en HTTPS.**


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


Cert-manager est un contrôleur Kubernetes open-source qui automatise la gestion des certificats TLS (Transport Layer Security) pour les applications s'exécutant dans un cluster Kubernetes. Il facilite la demande, l'émission et le renouvellement des certificats SSL/TLS en intégrant des fournisseurs de certificats tels que Let's Encrypt.

### *cert-manager.yml*

```consol

apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
 name: cert-manager
 namespace: default
spec:
 acme:
   server: https://acme-v02.api.letsencrypt.org/directory
   privateKeySecretRef:
     name: cert-manager-account-key
   solvers:
     - http01:
         ingress:
           class: traefik
```

```consol
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
```
### *ingress.yml*

```consol

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-vote
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd,default-ipwhitelist@kubernetescrd,default-redirect@kubernetescrd
    cert-manager.io/issuer: cert-manager
spec:
  tls: 
    - hosts: 
        - voting.simplon-raja.space
      secretName: tls-cert-ingress-http
  rules:
  - host: voting.simplon-raja.space
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



## **4/ Mettre en place une authentification avec certificats TLS client. Il faudra mettre en place une PKI et uniquement valider les certificats qui ont été générés via le Certificate Authority. Verifier que seuls les clients presentants un certificat valide sont autorises**

 
 1. Générer une autorité de certification (CA):
 
 ```conosl
 openssl genrsa -des3 -out 'ca.key' 4096
 openssl req -x509 -new -nodes -key 'ca.key' -sha384 -days 1825 -out 'ca.crt'
```
- Creation du secret

### *secret.yml*

```consol
apiVersion: v1
kind: Secret
metadata:
  name: client-auth-ca-cert
type: Opaque
data:  
  ca.crt: *****

```

```consol 
base64 -i ca.crt -> Pur genere le secret chiffre en base 64
```
```consol 
echo -n '' -> permet de filtre le caractere speciaux.
```
```
 
2.Ajouter le certificat CA à Traefik

### *tlsoption.yml*

```consol

apiVersion: traefik.containo.us/v1alpha1
kind: TLSOption
metadata:
  name: client-cert 
  namespace: default 
spec:
  minVersion: VersionTLS12
  maxVersion: VersionTLS13
  clientAuth:
    secretNames:
      - client-auth-ca-cert
    clientAuthType: RequireAndVerifyClientCert
  curvePreferences:
    - CurveP521
    - CurveP384
  cipherSuites:
    - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
    - TLS_AES_256_GCM_SHA384
    - TLS_CHACHA20_POLY1305_SHA256
  sniStrict: true

```
### *ingress.yml*

```consol
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-vote
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd,default-ipwhitelist@kubernetescrd,default-redirect@kubernetescrd
    traefik.ingress.kubernetes.io/router.tls.options: default-client-cert@kubernetescrd
    cert-manager.io/issuer: cert-manager
spec:
  tls: 
    - hosts: 
        - voting.simplon-raja.space
      secretName: tls-cert-ingress-http
  rules:
  - host: voting.simplon-raja.space
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

curl -vk https://example.com 
curl -vk  https://vote.simplon-raja.space

![](https://hackmd.io/_uploads/Bkl_FbVKh.png)

![](https://hackmd.io/_uploads/H1KFtWEF2.png)

3. Générer un certificat client

```consol
export DOMAIN=voting.simplon-raja.space
export ORGANIZATION=raja-cert
export COUNTRY=fr

openssl genrsa -des3 -out "voting.simplon-raja.space.key" 4096
openssl req -new -key "voting.simplon-raja.space.key" -out "voting.simplon-raja.space.csr" -subj "/CN=voting.simplon-raja.space.key/O=raja-cert/C=fr"

openssl x509 -sha384 -req -CA 'ca.crt' -CAkey 'ca.key' -CAcreateserial -days 365 -in "voting.simplon-raja.space.csr" -out "voting.simplon-raja.space.crt"
openssl pkcs12 -export -out "voting.simplon-raja.space.pfx" -inkey "voting.simplon-raja.space.key" -in "voting.simplon-raja.space.crt"
```

![](https://hackmd.io/_uploads/ryIAeSVYh.png)


## **5/ Retirer l’authentification simple par mot de passe local sur Traefik. Mettre en place une authentification OAuth avec Google ID afin d’autoriser les utilisateurs à l’aide de leur compte Google.**

1. Creer un projet sur: https://console.cloud.google.com/apis/dashboard?project=brief11

2. Creer un ForwardAuth, créer un secret contenant les information sont a
acquises à partir de la console de développement. Dans la partie de Google Informations supplémentaires on trouve: le ID client et Client secret ed on doit chiffre le MDP par la commande suivant: 

```consol
echo "mettre le MDP" | base64
```
Pour obtenir le MDP secret on doit faire la commande suivante : *openssl rand -hex 16* et le chiffre aussi avec la commande: echo "mettre le MDP" | base64.

```consol
apiVersion: v1
kind: Secret
metadata:
  name: traefik-sso
type: Opaque
data:  
  clientid: ******************
  clientsecret: **************
  secret: ********************
```

### *traefik-sso.yml*

```consol
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: traefik-sso
  name: traefik-sso
spec:
  progressDeadlineSeconds: 2147483647
  replicas: 1
  revisionHistoryLimit: 2147483647
  selector:
    matchLabels:
      app: traefik-sso
      name: traefik-sso
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: traefik-sso
        name: traefik-sso
    spec:
      containers:
      - env:
        - name: PROVIDERS_GOOGLE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              key: clientid
              name: traefik-sso
        - name: PROVIDERS_GOOGLE_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              key: clientsecret
              name: traefik-sso
        - name: SECRET
          valueFrom:
            secretKeyRef:
              key: secret
              name: traefik-sso
        - name: COOKIE_DOMAIN
          value: simplon-raja.space
        - name: AUTH_HOST
          value: voting.simplon-raja.space
        - name: INSECURE_COOKIE
          value: "false"
        - name: WHITELIST
          value: choukri.raja1@gmail.com
        - name: LOG_LEVEL
          value: debug
        image: thomseddon/traefik-forward-auth:2
        imagePullPolicy: Always
        name: traefik-sso
        ports:
        - containerPort: 4181
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
status: {}
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-sso
spec:
  selector:
    app: traefik-sso
  ports:
  - protocol: TCP
    port: 4181
    targetPort: 4181

```

### *sso.yml*

```consol
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: traefik-sso
spec:
  forwardAuth:
    address: http://traefik-sso:4181
    authResponseHeaders: 
        - "X-Forwarded-User"
    trustForwardHeader: true
```

### *ingress.yml*

```consol
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd,default-ipwhitelist@kubernetescrd,default-redirect@kubernetescrd,default-traefik-sso@kubernetescrd
    traefik.ingress.kubernetes.io/router.tls.options: default-client-cert@kubernetescrd
    cert-manager.io/issuer: cert-manager
spec:
  tls: 
    - hosts: 
        - voting.simplon-raja.space
      secretName: tls-cert-ingress-http
  rules:
  - host: voting.simplon-raja.space
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
