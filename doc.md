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
htpasswd -nb raja ******** | openssl base64
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

##  **4/ Mettre en place une authentification avec certificats TLS client. Il faudra mettre en place une PKI et uniquement valider les certificats qui ont été générés via le Certificate Authority. Verifier que seuls les clients presentants un certificat valide sont autorises**

 
 1. **Générer une autorité de certification (CA):**
 
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
  ca-crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZRVENDQXltZ0F3SUJBZ0lVRUQvczVEUGVnM0FONnlGUHdwcm03dFU2WG9Vd0RRWUpLb1pJaHZjTkFRRU0KQlFBd01ERUxNQWtHQTFVRUJoTUNSbEl4SVRBZkJnTlZCQW9NR0VsdWRHVnlibVYwSUZkcFpHZHBkSE1nVUhSNQpJRXgwWkRBZUZ3MHlNekEzTURVeE1EQTVNamhhRncweU9EQTNNRE14TURBNU1qaGFNREF4Q3pBSkJnTlZCQVlUCkFrWlNNU0V3SHdZRFZRUUtEQmhKYm5SbGNtNWxkQ0JYYVdSbmFYUnpJRkIwZVNCTWRHUXdnZ0lpTUEwR0NTcUcKU0liM0RRRUJBUVVBQTRJQ0R3QXdnZ0lLQW9JQ0FRQzJ3a0lKK2RlSHNtSGsvdTdSZGVqeXQwVHNBME01ZmRrSApvdFNRMXkyZzByWHFrMVEvRTFCZWdOMllIazBpZlZqZURhbCtOTnJiZHN4UFdTNW1ib29iS0NVdkRUcDBBRm1WCk1zWm9ETlNSemlkc3hqd0d2eGVBUEhZUEtBVWhYNDFUTnlOR2xRcTI4bFZqdEprUHNleUgzeFN3Z3lSd1RSSkoKWkQ3OUVZSm1LS2QyUDhsYUs2U25YcEFMZHFlVFhwN2hkMHVDc0YwTDJXckk5eTRab3YzZ3V4R1VhYndRMGpVRgp2RkdNOVg3VW5Pd0k5aU14bnkyUS8yYXIvS0xFSUVtYi9ENFp2UzNYaEhsLzFzcGxpZnFQWkkrOUJudk1LaFRECi8wRnRSSk5xbjcrR1R1OWhWS2lGNGhGY1J3SGFxc3VEWURGUkVPakxRVVpkT2FkUm5peXI5THVwclRJbzA4WFUKTXB3Znd3MmlrYnhPbjRPUFNacFBWZU1CMEhtMGZRcisvY2tRakNMRlB0Si9zbDluNmJHaTBLS1U0Zk9EaDdDNgovaXZmcHdWc09vQmJwR1BuaTk2bG0yRHBJVXNMOXFidjNCZklubng1WXFlQU1XcGMwZmNXSU1zNmFic1VuMWZFCndzbXN4MVc1SWMrK01VcFgzbmdZR09iamlZaWhvMm9XZmdjYjQ3Q3Z4WkNhckJIR3p4U3U0endDMGYxM0tITysKRkRvZGZOV3MvbVRNaXJCZ2QzQWRjWkNDTDF1VFhOalNSRTVrdmVTU2UxaUVNMkNSTGhMOUVUczNjTW5nU3NJOAppNDIrbmlleTNXdVZ3a2JBL1NMVlVPRmdvY1hwQmlsWHRWU3Ywc2pVaVEzTnIzSmk0aFNRZzEwR2dOeTBQYjVHCmQ4VDdiUUdhb1FJREFRQUJvMU13VVRBZEJnTlZIUTRFRmdRVUlyZlZVVis1dldTMGpTVUJ6cElZSUdZYXBpMHcKSHdZRFZSMGpCQmd3Rm9BVUlyZlZVVis1dldTMGpTVUJ6cElZSUdZYXBpMHdEd1lEVlIwVEFRSC9CQVV3QXdFQgovekFOQmdrcWhraUc5dzBCQVF3RkFBT0NBZ0VBanVMUDFiMTdHbjFEeHpmUG5wVlFsRmxpcThmWkgxVFc4aG5RClgrWW1JV0Zkb3RCYnM5R0pjNnJITkF3N0ljdWpnRGxUaXQ0aFJ0VldBRCs2V0xjN2tqSzNmY2d4SVg3QkhjcVEKU2NDWU01VVV1VjhnMlRhZ2gxalhCQ2FFSkNnR2hoR3RaWFpHOTkvY0NFcWcrUWp6ZnRaUjRyZ245TDA5bWxudgpBcDhSeEdtTVRxMXJrL3F2a0YyaGZjYnZEczBOMmhEeHhRZzc1VU9OZW1ySEo0eDRHV1RnMi9uYWczMGtxRjZKCjk1VGd4bGY5ZWxmTjNzSFMzcmFxUi9sNXhrVGxCNVlwQTg4Z3I3K1pVMGFYbE4xTVQ1Z3RMM2dFckZuV0J2TEIKM2NGT203RlNNSVVjUzZCSldQKzd0QklPbW52ai8vZk10NGRnRUtZYlpFc3MvVStHbENqYk9maUJMRElQM0xKRgovNjNhVFlUSmVxcFBPd0dYQWVDbEFPdHN0STN6azVQcGhhaURZSThCWjFEdXlaSDhXZmMrSGtRdWN1TjFTTFBECjRnL0h2cS9TUFFmWngwa1hGMlkwL3c4azA3ZlNuNERGZDFiOWFxcC9SYjNUeUJPd1VTcVlnZzBVbHpUN3UvL0EKM1UrMWtQR3FYWmlSbUdQenJoNHQvOFBiN3lGMllpWWJMR1dOTXUxVng1Z29PUGNnWVRtMW9ZRTQ5aXFFOXJrdwp0Y2EyN0JhcHRjMmxMazVHUE12OUZ3NGNKVW9aMHdzSmlGR3lsS3ZPNmhRUTZySFJvejNFZjVMUUF3UmxJbDJ2Cm5IV0JEckwrajlaVVlLU3dsOW5iTmJPdVN1OTRoS0x3cnFhZHpnY3AwVTRLaExuVHhOQmJPUVdRVTNIaThlT1kKOTB2dVBGRT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=

```
```consol 
base64 -i ca.crt -> Pur genere le secret chiffre en base 64
```
```consol 
echo -n '' -> permet de filtre le caractere speciaux.
```
```
 
2. **Ajouter le certificat CA à Traefik**

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
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.middlewares: default-basicauth@kubernetescrd,default-ipwhitelist@kubernetescrd,default-redirect@kubernetes
    traefik.ingress.kubernetes.io/router.tls.options: default-client-cert@kubernetescrd
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

curl -vk https://example.com 
curl -vk  https://vote.simplon-raja.space

![](https://hackmd.io/_uploads/Bkl_FbVKh.png)

![](https://hackmd.io/_uploads/H1KFtWEF2.png)

4. Générer un certificat client

```consol
export DOMAIN=voting.simplon-raja.space
export ORGANIZATION=raja-cert
export COUNTRY=fr

openssl genrsa -des3 -out "voting.simplon-raja.space.key" 4096
openssl req -new -key "voting.simplon-raja.space.key" -out "voting.simplon-raja.space.csr" -subj "/CN=voting.simplon-raja.space.key/O=raja-cert/C=fr"

openssl x509 -sha384 -req -CA 'ca.crt' -CAkey 'ca.key' -CAcreateserial -days 365 -in "voting.simplon-raja.space.csr" -out "voting.simplon-raja.space.crt"
openssl pkcs12 -export -out ".pfx" -inkey "voting.simplon-raja.space.key" -in "voting.simplon-raja.space.crt"
```

## **5/ Retirer l’authentification simple par mot de passe local sur Traefik. Mettre en place une authentification OAuth avec Google ID afin d’autoriser les utilisateurs à l’aide de leur compte Google.**
