---
layout: post
title: "Cleaning Unused Docker Data Without External Tools"
category: blog
ref: docker-system-prune
lang: en
---

*Warning: read the full article before typing commands you may regret.*

If you are a docker user (may it be in production or on your development
machine), you may have accumulated quite a bit of useless data by now. There
are existing tools to clean your daemon of unused images and containers (like
[docker-gc]), but since the [docker API 1.25][api-125] there is an easy to
use `prune` command that could be good enough for you.

Basic usage is pretty simple:

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
... approximately 2 gajillion hashes later...

Total reclaimed space: 5.64GB
```

That's nice, but it does not clean everything unused. For that you should add
the `--all` option to remove every image and not only the dangling ones:

```
WARNING! This will remove:
        - all stopped containers
        - all networks not used by at least one container
        - all images without at least one container associated to them
        - all build cache
Are you sure you want to continue? [y/N] y
... moar hashes...

Total reclaimed space: 26.78GB
```

Of course that may not be ideal. Having caches is pretty useful after all. And
there is just the option for that: `--filter` (only available starting at [API
1.28][api-128]). At the time of my writing there are only two filters: `until`
and `label`. In my case I only use the `until` one which allows you to clean
everything older than a specified timestamp.

Of course I don't put a timestamp in the command, I use `date` to generate a
timestamp based on a human readable date:

```
$ sudo docker system prune --all --filter until=$(date -d "1 month ago" +%s)
```

This command uses a substitution via `$( command )`, this allows you to get the
result of a command and inject it in another one as a string. The date command
itself is decomposed as: `date -d <time description> <time format>`, where
`+%s` is the format to get a timestamp. You can check `man date` for more info.

And voilà :smiley: I rarely need the cache to be older than a month on my
laptop (and one month is already pretty conservative, but that's because I
rarely have a good internet so I cache as much as I can).

Finally, if you feel adventurous enough you can add the `--force` option so
that the command will not ask for confirmation. I use the following in a
cronjob on my continuous integration server:

```
$ sudo docker system prune --force --all --filter until=$(date -d "1 week ago" +%s)
```

Happy cleaning :recycle:

*A note about `sudo`: on my dev machine (which is a GNU/Linux system) I only
use docker via `sudo` because not doing so mean that your user has the same
power as root all the time. This is due to the fact that the docker daemon is a
privileged process running as root. See the official [Docker
security][docker-security] page.*

[docker-gc]: https://github.com/spotify/docker-gc
[api-125]: https://docs.docker.com/engine/api/v1.25/
[api-128]: https://docs.docker.com/engine/api/v1.28/
[docker-security]: https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
