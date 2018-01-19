---
layout: post
title: Relancer une commande jusqu'à ce qu'elle réussisse
category: blog
ref: until-command
lang: fr
date: '2018-01-19 18:52:27+07:00'
---

Régulièrement, je me retrouve à copier de gros fichiers via `rsync`, et étant
donné que je suis souvent dans des endroits sans connexion Internet
stable, je me retrouve à relancer `rsync` plusieurs fois jusqu'à la réussite
de la commande.

Il est possible d'utiliser `while` pour ça, mais `while` continue de tourner
tant que son test réussi, du coup il faut capturer le code de retour, tester
la condition contraire, etc. Donc à moins de faire un petit script ça fait
beaucoup à taper juste pour une commande *ad hoc*.

C'était sans compter sur l'existence de la commande `until`, qui vas continuer de relancer la commande
 tant qu'elle échoue.

Ça s'utilise de la manière suivante :
```bash
$ until <mettre la commande ici>; do echo "Retrying at `date -Iminutes`"; done
```

Donc avec `rsync` ça donne :
```bash
$ until rsync -aP src:/path/to/copy dest/; do echo "Retrying at `date -Iminutes`"; done
```

Et si vous êtes vraiment fainéant, vous pouvez toujours faire un alias (laissé en exercice pour le
lecteur ;) ).

