---
layout: post
title: "Économiser du temps et de la bande passante avec un cache Docker local"
category: blog
ref: caching-docker-image-local-registry
lang: fr
---

Régulièrement, j'utilise Docker 🐳 dans des VMs (vagrant) ou sur d'autres
machine de mon réseau local, et je me retrouve à télécharger plusieurs fois la
même image sur ces différentes machines. En plus du gâchis de bande passante,
ça devient rapidement une grosse perte de temps sur de petites connexions !
Pour régler ce problème j'utilise maintenant registre (« registry ») Docker en
local qui cache de manières transparentes toutes les images récupérées par
Docker. Voici comment mettre cela en place.

D'abord, un peu de préparation. Nous allons créer un dossier qui va être
utilisé par le registre pour stocker  toutes ces données. Ce dossier peut-être
n'importe où sur votre machine, personnellement je l'ai mis dans `/var/lib` :

```
$ sudo mkdir /var/lib/docker-registry
```

Nous allons ajouter la configuration par défaut du registre dans ce dossier, et
pour cela on va directement l'extraire depuis l'image Docker :

```
$ sudo docker run -it --rm registry:2       \
       cat /etc/docker/registry/config.yml  \
       > /var/lib/docker-registry/config.yml
```

La configuration pourra être différente selon le moment ou vous la récupérez, à
la création de cet article elle ressemblait à ça :

```yaml
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

Pour activer la fonction de proxy du serveur, il faut ajouter la configuration
suivante au fichier yaml:

```yaml
proxy:
  remoteurl: https://registry-1.docker.io
```

La clé `remoteurl` peut pointer vers n'importe quel registre, ici j'ai mis
celui de docker par défaut.

La configuration finale ressemble à ça:

```yaml
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://registry-1.docker.io
```

Maintenant que la configuration est finie, on peut démarrer notre registre. À
noter que j'ai utilisé l'option `--restart=always` dans la commande suivante
pour m'assurer que le registre démarre automatiquement avec le démon Docker.

```
$ sudo docker run --restart=always -p 5000:5000                         \
         --name v2-mirror -v /var/lib/docker-registry:/var/lib/registry \
         --detach registry:2 serve /var/lib/registry/config.yml
```

On utilise `-v` pour monter le dossier créé précédemment dans l'image, et on
démarre le registre avec l'option `serve` suivit du chemin vers le fichier de
configuration.

Assurons-nous d'abord que le container est bien lancé avec `docker ps`:

```
$ sudo docker ps
CONTAINER ID   IMAGE        CREATED          STATUS          PORTS                    NAMES
67425da4ea4c   registry:2   32 seconds ago   Up 29 seconds   0.0.0.0:5000->5000/tcp   v2-mirror
```

On peut ensuite lister le contenu du registre (vide) via `curl` :

```
$ curl http://localhost:5000/v2/_catalog
{"repositories":[]}
```

Maintenant que notre registre est actif, on va configure docker pour qu'il
l'utilise. Pour cela il faut éditer le fichier `/etc/docker/daemon.json` pour
ajouter la configuration suivante (qui doit être du JSON valide) :

```json
{
    "registry-mirrors": ["http://localhost:5000"]
}
```

Il est possible que ce fichier (voir dossier) n'existe pas sur votre système.
Si c'est le cas, vous pouvez le créer manuellement (avec l'utilisateur `root`).
Une fois la configuration changée il faut redémarrer docker. Ici j'assume que
vous avez un système qui utilise Systemd:

```
$ sudo systemctl restart docker
```

Nous sommes maintenant prêts à réaliser notre premier download pour vérifier que
le proxy fonctionne correctement:

```
$ sudo docker pull redis
Using default tag: latest
latest: Pulling from library/redis
f17d81b4b692: Pull complete
b32474098757: Pull complete
8980cabe8bc2: Pull complete
e614c66c2b9c: Pull complete
6eb43ec9256b: Pull complete
394ecf5f46d4: Pull complete
Digest: sha256:f30f134bd475d451ce3207fb128bcef8ff87d0f520a39cac0c4ea285819c42a9
Status: Downloaded newer image for redis:latest

~ took 40s
```

Vérifions que l'image est maintenant dans notre registre local:

```
$ curl http://localhost:5000/v2/_catalog
{"repositories":["library/redis"]}
```

Et voilà ! Nous venons de cacher notre première image 🎉. Vérifions maintenant
que le cache fonctionne comme il faut. En premier lieu, on va effacer l'image
de notre démon docker:

```
$ sudo docker rmi redis
Untagged: redis:latest
Untagged: redis@sha256:f30f134bd475d451ce3207fb128bcef8ff87d0f520a39cac0c4ea285819c42a9
Deleted: sha256:415381a6cb813ef0972eff8edac32069637b4546349d9ffdb8e4f641f55edcdd
Deleted: sha256:2a5a57892da005399e6ce7166c5521cdca43a07872f23995e210bde5dae2640e
Deleted: sha256:85e1fabde4fd4d6df993de44ef3e04d15cd69f9d309c0112c6a5054a6dc8351a
Deleted: sha256:2725175b62c7479ee209454110e8293080b9711e4f0a29219e358d1afba88787
Deleted: sha256:7ae66985fd3a3a132fab51b4a43ed32fd14174179ad8c3041262670523a6104c
Deleted: sha256:bf45690ef12cc54743675646a8e0bafe0394706b7f9ed1c9b11423bb5494665b
Deleted: sha256:237472299760d6726d376385edd9e79c310fe91d794bc9870d038417d448c2d5
```

Et on la récupère de nouveau:

```
sudo docker pull redis
Using default tag: latest
latest: Pulling from library/redis
f17d81b4b692: Pull complete
b32474098757: Pull complete
8980cabe8bc2: Pull complete
e614c66c2b9c: Pull complete
6eb43ec9256b: Pull complete
394ecf5f46d4: Pull complete
Digest: sha256:f30f134bd475d451ce3207fb128bcef8ff87d0f520a39cac0c4ea285819c42a9
Status: Downloaded newer image for redis:latest

~ took 13s
```

Ce qui nous a pris 3x moins de temps ! 👍 Le téléchargement était quasiment
instantané, et seule la décompression a pris du temps.

Avec ça nous avons maintenant un cache local transparent pour toutes les images
Docker que l'on télécharge. On peut maintenant pointer les différentes VM ou
machine du réseau vers ce cache, et profiter du temps gagner pour faire des
choses utiles plutôt que de télécharger des octets depuis internet :)

Un effet secondaire intéressant de ce cache, et que si un `docker pull` échoue
au milieu du téléchargement, les images intermédiaires déjà télécharger seront
conservée dans le cache, et donc il ne sera pas nécessaire de les télécharger
de nouveau. Vous pouvez vérifier ça en stoppant un `pull` et en le relançant
avec et sans le proxy.
