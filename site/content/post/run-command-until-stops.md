---
layout: post
title: Running a command in your shell until it succeed
category: blog
translationKey: until-command
lang: en
date: '2018-01-19 18:52:42+07:00'
aliases:
  - /blog/run-command-until-stops/
---

I am regularly copying big files over the internet via `rsync`, and since I am
travelling a lot, I don't generally have access to stable internet connection,
so I end-up rerunning the command multiple times until it succeeds.

Turns out there is a better way. Of course you could use `while` and test the
return of the command, but that sounds like a lot of work for a *ad hoc*
command. But I am lazy and I recently discovered that an `until` command exists!

Pretty straightforward to use:
```bash
$ until <put your command here>; do echo "Retrying at `date -Iminutes`"; done
```

So with `rsync` you get:
```bash
$ until rsync -aP src:/path/to/src dest/; do echo "Retrying at `date -Iminutes`"; done
```

And if you are really lazy, just create an alias (left as an exercise ;) ).

