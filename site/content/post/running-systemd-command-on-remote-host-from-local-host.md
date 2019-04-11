---
layout: post
title: "Running Systemd commands on remote host from your local host"
category: blog
translationKey: remote-systemd-command-from-local
lang: en
date: 2018-10-22
aliases:
  - /blog/running-systemd-command-on-remote-host-from-local-host/
---

While I was reading the [pretty awesome Archlinux wiki][arch-wiki] for
something completely different, I found out that one can launch any `systemctl`
command to a remote host via the `--host` (or `-H`) flag.

So let say you want to check the `cron` process on a server named kitten:
```
$ systemctl -H root@kitten status cron
● cron.service - Regular background program processing daemon
   Loaded: loaded (/lib/systemd/system/cron.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2018-07-28 11:36:37 CST; 2 months 25 days ago
     Docs: man:cron(8)
 Main PID: 1045
    Tasks: 1 (limit: 4643)
   CGroup: /system.slice/cron.service
           └─1045 /usr/sbin/cron -f
```

Nice right? Under the hood this use SSH so you must have access to the host.
And you can, of course, use any `systemctl` command, not just `status` ;)

Have fun 👋

[arch-wiki]: https://wiki.archlinux.org/index.php/systemd
