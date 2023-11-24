# ***PROJET***

## **TERRAFORM**

- Deployer l'infrastructure cloud aver terraform.
Pou faire ca il faut creer les fichier suivants: 

* *main.tf*
* *variable.tf*
* *providers.tf*

Pour lancer terraform -> **terraform init**

La commande *plan* est utilisée avec Terraform, un outil d'infrastructure en tant que code (IaC) utilisé pour définir, créer et gérer l'infrastructure de manière déclarative. -> **terraform apply**

Le commande terraform *apply* dans Terraform est utilisée pour appliquer les modifications définies dans le code d'infrastructure aux fournisseurs de cloud ou aux systèmes sur site. Après avoir exécuté terraform plan et évalué les modifications proposées. -> **terraform apply**

La commande *destroy* est utilisée avec Terraform pour supprimer complètement les ressources gérées par l'infrastructure spécifiées dans votre code Terraform. Cette commande est particulièrement utile lorsque vous souhaitez mettre hors service ou supprimer une infrastructure existante. -> terraform destroy**

## **INSTALLER AZURE CLI SUR LA MV**

Après avoir créé l'infrastructure cloud avec *Terraform*, on se dirige vers *AZURE* et récupère les *RDP* pour pouvoir accéder au *MV*. 

RDP -> ssh rj@40.118.121.37

- Sur la MV vituel j'installe *GIT*: 

1. Obtenez les packages nécessaires pour le processus d’installation 

```consol
sudo apt-get update
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
```
2. Téléchargez et installez la clé de signature Microsoft :

```consol
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
```

3. Ajoutez le référentiel de logiciels Azure CLI :

```consol
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
sudo tee /etc/apt/sources.list.d/azure-cli.list
```

4. Mettez à jour les informations concernant le référentiel, puis installez le package azure-cli:

```consol 
sudo apt-get update
sudo apt-get install azure-cli
```
## **INSTALLER GIT SUR LA MV**

```consol
sudo apt-add-repository ppa:git-core/ppa
sudo apt-get update
sudo apt-get install git
```

## **INSTALLER DOCKER SUR LA MV**

1. Installer les dépendances de Docker:

```consol
sudo apt-get update
```
2. exécutez la commande ci-dessous pour installer les paquets:

```cosol
sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common
```
3. Ajouter le dépôt officiel Docker

```consol 
sudo echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
```

4.  Ajoute le dépôt Docker à la liste des sources de notre machine:

```consol 
sudo echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
```

5. Mettre à jour le cache des paquets pour prendre en compte les paquets de ce nouveau dépôt :

```consol
sudo apt-get update
```

6. Installation des paquets Docker:
```consol
sudo apt-get install docker-ce docker-ce-cli containerd.io
```
- Vous pouvez regarder le statut de Docker -> *sudo systemctl status docker*
- Lister le image container -> *sudo docker image ls -a*
- Lister le container Docker -> sudo *sudo docker container ls -s*

## **INSTALLER KUBERNETES SUR LA MV**

1. Mettre à jour le cache des paquets

```consol
sudo apt-get update 
```

2. Installer kubectl:

```consol
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

## *CREATION AKS*

1. **Creation groupe de resources:** -> az group create --location westeurope --resource-group projet-raja

2. **Creation un cluster Aks** -> az aks create -g projet-raja -n AKSCluster --generate-ssh-key --node-count 2 --enable-managed-identity -a ingress-appgw --appgw-name myApplicationGateway --appgw-subnet-cidr "10.225.0.0/16"   

3. **Creation crediantials** -> az aks get-credentials --name AKSCluster --resource-group projet-raja

4. **Creation un database on Azure pour le server Mysql** -> az mysql server create --resource-group projet-raja --name mymsqlserver  --location westeurope --admin-user myadmin --sku-name GP_Gen5_2 --version 8.0  --ssl-enforcement disabled --tags AppProfile:WordPress

5. **Creation ACR-Azure Container Registry** -> az acr create --resource-group projet-raja --name projetacr --sku basic 

6. **Deployer image WordPress sur Docker** -> sudo docker pull wordpress:6.1.1

7. **Deployer container WordPress sur Docker** -> sudo docker create --name wordpress -p 80:80 wordpress:6.1.1

9. **Deployer image MYSQL sur Docker** -> sudo docker pull mysql:8

10. **Deployer container MYSQL sur Docker** sudo docker create --name mysql -p 5000:5000 

```consol
sudo docker create --name mysql -p 3306:3306 mysql:8
```

![](https://hackmd.io/_uploads/SJX9l7iAh.png)

8. **Deployer le container WordPress sur Docker**

```consol
sudo docker create --name wordpress -p 80:80 wordpress:6.1.1
```

![](https://hackmd.io/_uploads/HJDNQQjRn.png)

## ***BUILD WORDPRESS AVEC KUBERNETES***

1. *INSTALLER HELM*

```consol
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

2. *AJOUTER LE RÉFÉRENTIEL HELM DE TRAEFIK AUX REPOSITORIES*

```consol
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
```

3. *DÉPLOYER TRAEFIK AVEC HELM*

```consol
helm install traefik traefik/traefik
```

- **Creer un namespace**
Pour lancer la creation du namespace: *kubectl create namespace*
- **Creer le persistentvolume**
Pour lancer la creation du persistentvolume.yml *kubectl create -f persistentvolume.yml -n wordpress*
- **Creer le volume-claim** 
Pour lancer la creation du volume-claim *kubectl create -f volume-claim.yml -n wordpress*
- **Creer un secret.**
Pour lancer la creation d'un secret *kubectl create -f secret.yml -n wordpress*
- **Creer un deployment wordpress**
Pour lancer le deployment du wordpress *kubectl create -f deployment-wp.yml -n wordpress*
- **Creer un deployment mysql**
Pour lancer le deployment du wordpress *kubectl create -f deployment-mysql.yml -n wordpress*
- **Creer le service mysql**
Pour lancer le deploiement *kubectl create -f service-mysql.yml -n wordpress*
- **Creer le service wordpress**
Pour lancer le deploiement *kubectl create -f service-wp.yml -n wordpress*

J'ai afficher le site wordpress sur mon *DNS* -> **wordpress.raja-ch.me**
<img width="489" alt="Capture d’écran 2023-11-18 à 17 49 43" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/7a1d13cd-f74b-41bc-89d6-0567d6e38140">

Pour rendre le logiciel WordPress visible sur votre DNS, vous devez disposer d'un DNS au cas où vous pourriez l'acquérir une fois acquis deux fois et configuré.

Pour configurer votre DNS avec Gandi :
<img width="314" alt="Capture d’écran 2023-11-19 à 13 14 02" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/b01341a3-317f-41e4-9d48-0a525fcfa8ca">

## **Mettre en place une authentification BasicAuth HTTP avec mot de passe local dans la config de Traefik**

Pour pouvoir faire cela il faut créer le fichier middleware.yml dans lequel est également incluse la partie basicauth dans laquelle je vais crypter le mot de passe.

- **Middleware.yml**

```consol 
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: auth
spec:
  basicAuth:
    removeHeader: false
    secret: authsecret

---
apiVersion: v1
kind: Secret
metadata:
  name: authsecret
data:
  users:
    dXNlcjokYXByMSQwdERsbjBKZyR4LnlyUk8ubVltdm1mNmxUNG9rNWExCgo=

```
Pour chiffrer mdp, j'ai exécuté la commande suivante :

```consol
htpasswd -nb user password | openssl base64 
htpasswd -nb raja rajach | openssl base64
```
Enfin il faut aussi ajouter cet partie sur le fichier ingress.yml

<img width="616" alt="Capture d’écran 2023-11-19 à 15 18 52" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/a7428e5c-2cf8-4f9a-bbab-863bf223875b">

Après avoir créé le middleware.yml et mis à jour l'entrée, nous obtenons que lorsque nous essayons d'accéder à WordPress, il nous sera demandé de saisir les informations d'identification pour y accéder.

<img width="855" alt="Capture d’écran 2023-11-20 à 11 55 13" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/c26bbb24-8698-4927-9e3e-0db9f662ac18">

<img width="1100" alt="Capture d’écran 2023-11-20 à 11 49 31" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/d3a65a83-7b01-4916-b964-1e1d732b420a">

*NOM D'UTILISATEUR*: user
*MOT DE PASSE*: rajach

## **## *METTRE EN PLACE UN CERTIFICAT TLS SUR TRAEFIK LIÉ AU DOMAINE AVEC REDIRECTION EN HTTPS

Mettre en place un certificat TLS sur Traefik lié au domaine avec redirection en https*

1. *Installer le cert-manager*

- Installation de cert manager: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml

- Creer le fichier cert-manager.yml

```consol 
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
 name: cert-manager
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

- Faut ajouter la partie du cert manager sur ingress: 

Annotation: *cert-manager.io/issuer: cert-manager***

Il faut creer le fichier tls.yml 

```consol 

apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect
  namespace: wordpress
spec:
  redirectScheme:
    scheme: https
    permanent: true
```
Aprés il faut ajouter dans l'annotation sur l'ingress.

 <img width="960" alt="Capture d’écran 2023-11-24 à 11 28 59" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/ed18ee97-871c-4a3c-9b70-6beef4d93379">

- https://wordpress.raja-ch.me/wp-admin/install.php


## 2. *METTRE EN PLACE UNE AUTHENTIFICATION AVEC CERTIFICATS TLS CLIENT*

1. *Générer une autorité de certificat*

```consol
openssl genrsa -des3 -out 'ca.key' 4096
openssl req -x509 -new -nodes -key 'ca.key' -sha384 -days 1825 -out 'ca.crt'
```

2. *Creer le fichier secret-manager*

```consol
apiVersion: v1
kind: Secret
metadata:
  name: client-auth-ca-cert
type: Opaque
data:  
  ca-crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZhekNDQTFPZ0F3SUJBZ0lVQVVTS1F1c0ZpMjFQa3pmZmxSUXdVRHZyb0trd0RRWUpLb1pJaHZjTkFRRU0KQlFBd1JURUxNQWtHQTFVRUJoTUNSbEl4RXpBUkJnTlZCQWdNQ2xOdmJXVXRVM1JoZEdVeElUQWZCZ05WQkFvTQpHRWx1ZEdWeWJtVjBJRmRwWkdkcGRITWdVSFI1SUV4MFpEQWVGdzB5TXpFeE1qRXdPRFF5TURkYUZ3MHlPREV4Ck1Ua3dPRFF5TURkYU1FVXhDekFKQmdOVkJBWVRBa1pTTVJNd0VRWURWUVFJREFwVGIyMWxMVk4wWVhSbE1TRXcKSHdZRFZRUUtEQmhKYm5SbGNtNWxkQ0JYYVdSbmFYUnpJRkIwZVNCTWRHUXdnZ0lpTUEwR0NTcUdTSWIzRFFFQgpBUVVBQTRJQ0R3QXdnZ0lLQW9JQ0FRRFZNWk1ZaVRkZDVRV3dtdTZyRnNwT3l5cW0vNFFubERIQlExTGlNWnpXCllNOUE1TkNpZ0xNSFZyZEdyNHJ0OEdOZkJGa2tvbWMxK1YyVWlHM1VuQkJCYmVxcVFCS1JmY0lkazFzdlZCdm0KOGdDR2hOUjJIRmdTek9oOHdIWjdVRVlwalJiVGlkeUxqZXdHVHBESm43VkxxeHJpZkFHSG9jOVZPRmt5NTRrZwpGMXdqL240VWNhakN3a3hpOU42MFl2ME1PM01HZmhtWUpiZDFhaGVscVpBQWF3QWJWMXZLOWgyWWtCVXlVcHExClVNRk90Z0hUYXJzUW53Nk1oSHFnYzFnS292MFZJSkM3Qy9BbHhOK3lySjg1M1ZadERjME0yeC8zSEk3T3V1THMKbytvaVZvSjdnMXZTRHVDZ1FVZEY2NVlGbmtab1ZJbFk3L3pLL3h0eDYybndUdlVENVpxQUx3OGwxYTg1RzJKUApOUnFZMGNLUHFnUjZ6MWJpRVRERXQ1OFdOTFZjZWxna0NNTDdXV0dNcXg2OFJNaEUvVHNiMXYyTVRtVisraUIyCitUWlpoMW9UQXFwWCt6clVGSktNMm16QzkvL2REU2FPem9EMm5hNG1UVmVaR290MkNPanpXUWJRaWxzSzVpVWcKV3dEOW43aDdJdnJLR1lQSkhBZDZRTXFHRDJzMzUrWDNUazZIazZWT1JaRkZWaDJqQTRraFF0R2I5bW94NlBwdgpZeURYa2xQL0pJQThEU3NXWTI1T3FlMHNsM3RUZUZzOVlML0plQXorV1E4K2dHUU85bDQyUkYwTmpqcUZxVzdtClVpOTU4NTFxRHN3bzQ3ZG5RbnplL0JBYU8yUThZRndZS3F3NUJELzVJT2x2dmw5YlQwTnYwMWFqb2VUcUdGTTMKUndJREFRQUJvMU13VVRBZEJnTlZIUTRFRmdRVXVtaDBVU21acTB3Rnp3cElXQTlNSEZ0b2ZWWXdId1lEVlIwagpCQmd3Rm9BVXVtaDBVU21acTB3Rnp3cElXQTlNSEZ0b2ZWWXdEd1lEVlIwVEFRSC9CQVV3QXdFQi96QU5CZ2txCmhraUc5dzBCQVF3RkFBT0NBZ0VBalRzb2RSNlpwZE9acW04NDJrd0htYmcxRzBxWlQyOHZjODhkYXdFdTZsQUoKQzhKRThKSVlLdG4zZ0d4cU1UV2dzN0QrbGZVY0JDcDV3QjYzRXBsTHA4bkRMUm9URTNqcldETEU3cWtvNC8vUApXckpHNWlBUTNqWmUvbmZHUFpvRXdPbm1HMm54ak56SXkyUlZ2Y0RLcm9zQWE4anZQT0svY1E1cVhha0JkVVVVCnN5ZHBMSkFUdlF3MHNzMFpXTlAwQWFLNFJiT1ZBQnp6aFpNb0hOSGRoa1FoYjZOa3kyTGVsMVRPNm1VMzVmY0IKZ0RhTGMvNXJoaWZiWW1jeTNWZ280MjlmSW9HK05nVmFrMk94SjBMSmdFRmEwVFd3Uk1zMzNTK0hzOWtyY2NFNApLYXJQa1hyZmZadkJVbTZ5amRhZVNQSXhPeE5jVEhNZnRITHRNUmRFbEVvZ0xqVW01bGFEaksyM1ovaUJUdEllCmVQN1JHNWN2NkpWYnd2VXA0T3pLaVJaejVZTllNVGpaazdiTUFmV2lBOENkdkVUMjF0bFdNM0lVNWs5NWV6VjkKSXE3U1J4VmR2d21BbG5zS1k4T2JMZ05WUGNGMWVuckFOaTJiTExQWU9ndmRnMmtxaFc2UFVXRHRCODNVTWxrOQo5ZlR3KzJQekVFRDdrRGFVQU1ITkVVS1R4T2JjWXNVQVZhOXZFdDZrbzJpZnlrS3VueW1HaWs2cjlHTGVzWnhiCm9qRmZ6RmJoUFBERUdjMzM4K2xhUEYwU3owS2NKVFN0NDhSRldGc2hkdzlDUi9xbFdyTUljbHc2Q2pGcCtvUXUKOFdXRFVPdm9iMUhQSENuelQ5ZVpLdWorOTU0N25xak9ldHB2TEMxWXZMN0UzandzdjFiSEFBcncyRFNIT2lFPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
  
```
3. *Ajout du certificat sur Traefik avec une TLS option qui vérifie le certificat client:*

- Creer le fichier tls-option.yml
```consol 
apiVersion: traefik.containo.us/v1alpha1
kind: TLSOption
metadata:
  name: client-cert
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

- Il faut ajouter cette partie sur le fichier *ingress.yml*

```consol
  traefik.ingress.kubernetes.io/router.tls.options: wordpress-client-cert@kubernetescrd
```
- Test sans certificat client avec: *curl -vk https:///wordpress.raja-ch.me/*

**PROBLEM**: 

401 -> Unauthorized
<img width="577" alt="Capture d’écran 2023-11-24 à 13 42 24" src="https://github.com/simplon-choukriraja/projet-raja/assets/108053084/46fc123b-a919-44ac-ace0-82a491b73e3e">

*SOLUTION*: curl -vk --user user:password https://wordpress.raja-ch.me/
            curl -vk --user raja:rajach https://wordpress.raja-ch.me/

- *Générer un certificat client*

```consol 
export DOMAIN=wordpress.raja-ch.me
export ORGANIZATION=raja-cert
export COUNTRY=fr

openssl genrsa -des3 -out "wordpress.raja-ch.me" 4096
openssl req -new -key "wordpress.raja-ch.me.key" -out "wordpress.raja-ch.me.csr" -subj "/CN=wordpress.raja-ch.me.key/O=raja-cert/C=fr"

openssl x509 -sha384 -req -CA 'ca.crt' -CAkey 'ca.key' -CAcreateserial -days 365 -in "wordpress.raja-ch.me.csr" -out "wordpress.raja-ch.me.crt"
openssl pkcs12 -export -out ".pfx" -inkey "wordpress.raja-ch.me.key" -in "wordpress.raja-ch.me.crt"
```
*PROBLEM*

<img width="1199" alt="Capture d’écran 2023-11-24 à 14 22 01" src="https://github.com/simplon-choukriraja/Brief11/assets/108053084/413ff697-aa47-4360-a836-7285777f8417">
## *DEPLOYER JENKINS*

*SOLUTION*
----

- **Creer un Dockerfile**

```conosl 
FROM jenkins/jenkins:lts
USER root 
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && \  
    apt install -y jq parallel  && \
    curl -sSL https://get.docker.com/ | sh
```
Lancer la commande suivantes pour creer Dockerfile:

- *docker build . -t jenkins*

- **docker-compose.yml**

```consol
version: '3.8'
services:
  jenkins:
    build : .
    privileged: true
    user: root
    ports:
     - 8080:8080
     - 50000:50000
    container_name: jenkins-projet
    volumes:
      - ./jenkins_configuration:/var/jenkins_home
      - /usr/bin/kubectl:/usr/bin/kubectl
      - /var/run/docker.sock:/var/run/docker.sock
```
Lancert la commande suivantes pour faire marcher jenkins: 
- *sudo docker-compose up -d*





