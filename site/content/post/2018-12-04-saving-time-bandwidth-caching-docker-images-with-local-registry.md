---
layout: post
title: "Saving Time and Bandwidth by Caching Docker Images With a Local Registry"
category: blog
translationKey: caching-docker-image-local-registry
lang: en
date: 2018-12-04
---

On a regular basis I use Docker 🐳 in VM (vagrant), or on various machines of
my local network. This lead me to download images on one machine while those
were already downloaded on another one. Beside the waste of bandwidth, on a low
speed or crowded connection this is also a huge waste of time! To solve this
issue, I am now running a local registry on my laptop that automatically cache
any images I request via docker.

To achieve this, we are going to run the official Docker registry in proxy
mode, and then we will instruct our Docker daemon to use this local registry as
its default one.

First we need to create a folder that will be used by the registry to store all
the images and data it needs. It can be anywhere on your machine, I personally
put it in the somewhat standard `/var/lib` folder:

```
$ sudo mkdir /var/lib/docker-registry
```

To ensure we have an up-to-date configuration file of the current registry
version, we can directly extract it from the docker image (and at the same
time, pull the image):

```
$ sudo docker run -it --rm registry:2 cat \
       /etc/docker/registry/config.yml > /var/lib/docker-registry/config.yml
```

Depending on your version of the docker registry image, the configuration may
be slightly different from mine. At the time of creation of this article it
looked like this:

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

To activate the proxy behaviour of the registry we have to had the following
key in the configuration:

```yaml
proxy:
  remoteurl: https://registry-1.docker.io
```

Where `remoteurl` is the URL of the remote registry to use by default. Here it
is Docker's official one.

The final configuration looks like this:

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

With the configuration done, we can start our local registry. Note that I have
added a `--restart=always` option flag in the command, so that each time the
Docker daemon will start the registry will also start automatically.

```
$ sudo docker run --restart=always -p 5000:5000                         \
         --name v2-mirror -v /var/lib/docker-registry:/var/lib/registry \
         --detach registry:2 serve /var/lib/registry/config.yml
```

In the command we use `-v` to mount our previously created registry folder in
the image, and we start the registry via `serve` with the configuration file as
the only parameter.

We can check that it is running:

```
$ sudo docker ps
CONTAINER ID   IMAGE        CREATED          STATUS          PORTS                    NAMES
67425da4ea4c   registry:2   32 seconds ago   Up 29 seconds   0.0.0.0:5000->5000/tcp   v2-mirror
```

We can query the content of our empty registry with `curl`:

```
$ curl http://localhost:5000/v2/_catalog
{"repositories":[]}
```

Now that we have our local registry running we have to configure the Docker
daemon so it will use it instead of the default one. This requires a change in
the `/etc/docker/daemon.json` file (as `root`):

```json
{
    "registry-mirrors": ["http://localhost:5000"]
}
```

This file and folder may not exist on your system yet. If so you can safely
create it. After the change we need to restart the daemon. Assuming your
system uses Systemd it should look like:

```
$ sudo systemctl restart docker
```

We can now try to download an image to see if it correctly use our caching proxy:

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

Let's check the content of the registry:

```
$ curl http://localhost:5000/v2/_catalog
{"repositories":["library/redis"]}
```

It seems that we just cached our first image 🎉. Let's try the caching then!
First we delete the redis image from our docker daemon:

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

And we pull it again:

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

Nice, 3x time quicker! 👍 With the download part was almost instant, and the
image decompression took most of the time!

And done! We now have a local cache for all our Docker images, that will start
each time the docker daemon is started. We can point all our VM or machines in
the network to it (by making listen to the outside). And we can now enjoy more
time to focus on what matter to us and less on downloading bits from the
internet :)

A nice effect of this caching is that intermediate images are also cached.
Which is really useful with unstable Internet access. Because now when the
connection is going to timeout in the middle of a pull, all the bits already
downloaded will be cached so you can continue your pull where you left it! You
can try that by starting to pull and image, stop it, then start it again. With
the default daemon without cache this leads to a downloading all of the
intermediate image again, but not with the proxy 👏
