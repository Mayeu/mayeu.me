---
layout: post
title: "Lancer une commande systemd sur un serveur distant depuis la machine locale"
category: blog
ref: remote-systemd-command-from-local
lang: fr
---

Alors que j'étais en train de lire [l'excellent wiki d'Archlinux][arch-wiki]
pour quelque chose de complètement différent, j'ai découvert qu'il était
possible d'utiliser l'option`--host` (ou `-H`) pour lancer une commande de
`systemctl` directement sur un serveur distant.

Par exemple, disons que vous vouliez vérifier la santé du processus `cron` sur
un serveur nommé `chaton`:
```
$ systemctl -H root@chaton status cron
● cron.service - Regular background program processing daemon
   Loaded: loaded (/lib/systemd/system/cron.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2018-07-28 11:36:37 CST; 2 months 25 days ago
     Docs: man:cron(8)
 Main PID: 1045
    Tasks: 1 (limit: 4643)
   CGroup: /system.slice/cron.service
           └─1045 /usr/sbin/cron -f
```

Pratique non ? Les commandes sont exécutées par SSH, il est donc nécessaire
d'avoir l'accès au serveur préalablement. Et ça n'est pas limité à `status`
n'importe quelle commande de `systemctl` va pouvoir être lancée comme cela ;)

Have fun 👋

[arch-wiki]: https://wiki.archlinux.org/index.php/systemd
