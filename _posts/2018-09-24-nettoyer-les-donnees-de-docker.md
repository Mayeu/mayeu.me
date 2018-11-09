---
layout: post
title: "Nettoyer les données non utilisées par Docker"
category: blog
ref: docker-system-prune
lang: fr
---

*Attention: lisez l'article en entier avant de taper une commande que vous
pourriez regretter.*

Si vous utilisez Docker (que ça soit en production ou sur votre machine de
développement) vous avez surement accumulé beaucoup de données maintenant
inutiles. Il existe des outils comme [docker-gc] pour nettoyer tout ça, mais
depuis [l'API 1.25][api-125] docker intègre la commande `prune` qui pourrait
suffire amplement.

L'usage de base est plutôt simple:

```
$ sudo docker system prune
WARNING! This will remove:
        - all stopped containers
        - all networks not used by at least one container
        - all dangling images
        - all build cache
Are you sure you want to continue? [y/N] y

Deleted Containers:
deleted: sha256:ea43728b2d10e7b0fe24036f9531caac96bd02f779b95a6620110f00ccd3b002
deleted: sha256:022db612b3070971ce7d51778806a1f995a9c3aa1a741a6c0be0bca603787387
...approximativement 2 gajillion de hashes...

Total reclaimed space: 5.64GB
```

Ça va enlever pas mal de choses, mais malheureusement pas tout ce qui est
inutilisé (les images sans containers par exemple ne sont par retirées avec
cette commande). Pour cela il faut ajouter l'option `--all`:

```
$ sudo docker system prune --all
WARNING! This will remove:
        - all stopped containers
        - all networks not used by at least one container
        - all images without at least one container associated to them
        - all build cache
Are you sure you want to continue? [y/N] y
... moar hashes...

Total reclaimed space: 26.78GB
```

C'est pas mal tout ça, mais pas encore idéal. Garder un peu de cache c'est
quand même utile pour accélérer les choses. Pour cela il y a l'option
`--filter` (disponible uniquement à partir de [l'API 1.28][api-128]). Au moment
ou j'écris ces lignes il n'y a que deux filtres disponibles: `until` et
`label`.  Dans mon cas j'utilise surtout `until` qui va tout nettoyer jusqu'à
une certaine date (utilisant un timestamp).

Évidemment, je ne m'amuse pas à taper un timestamp, mais j'utilise `date` pour
le générer:

```
$ sudo docker system prune --all --filter until=$(date -d "1 month ago" +%s)
```

Ici j'utilise une substitution avec `$( commande )` qui permet d'exécuter une
commande pour injecter son résultat sous forme de chaînes de caractères dans
une autre commande. La commande `date` se décompose en `date -d <description de
la date> <format de sortie>`. Ici le format de sortie `+%s` signifie
"timestamp". Jetez un oeil à `man date` si vous voulez en savoir plus.

Et voilà :smiley: J'ai rarement besoin de données plus vieilles qu'un mois (et
même 1 mois est très conservateur, mais comme j'ai rarement accès à un bon
débit je garde le plus possible).

Finalement, si vous avez l'âme d'un aventurier vous pouvez ajouter l'option
`--force` qui va lancer la commande sans confirmation nécessaire. Je l'utilise
sur mon serveur d'intégration continue dans une tâche cron:

```
$ sudo docker system prune --force --all --filter until=$(date -d "1 week ago" +%s)
```

Joyeux ménage :recycle:

*Une note à propos de `sudo`: sur ma machine de développement (qui est un
système GNU/Linux), j'utilise Docker exclusivement via `sudo`, car être dans le
group `docker` revient à donner les droits root à son utilisateur. Cela est dû
au fait que docker est un daemon privilégié sur le système. Plus d'info dans la
documentation officielle : [Docker security][docker-security].*

[docker-gc]: https://github.com/spotify/docker-gc
[api-125]: https://docs.docker.com/engine/api/v1.25/
[api-128]: https://docs.docker.com/engine/api/v1.28/
[docker-security]: https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
