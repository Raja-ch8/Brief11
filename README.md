# **Contexte du projet**

Pour atteindre ces objectifs, vous devrez :
​
1/ Mettre en place une authentification BasicAuth HTTP avec mot de passe local defini dans la config de Traefik.
​
2/ Mettre en place un filtrage d’adresse IP sur Traefik.
​
3/ Mettre en place un certificat TLS sur Traefik qui doit etre lie a votre domaine. Utiliser Let’s Encrypt pour cela. Les acces HTTP doivent etre interdits et/ou rediriges en HTTPS.
​
4/ Mettre en place une authentification avec certificats TLS client. Il faudra mettre en place une PKI et uniquement valider les certificats qui ont été générés via le Certificate Authority. Verifier que seuls les clients presentants un certificat valide sont autorises
​
5/ Retirer l’authentification simple par mot de passe local sur Traefik. Mettre en place une authentification OAuth avec Google ID afin d’autoriser les utilisateurs à l’aide de leur compte Google.
​
​
Objectif bonus :
​
6/ Retirer l’authentification OAuth avec Google ID. Mettre en place une authentification SSO via LDAP (serveur LDAP à installer et configurer).
