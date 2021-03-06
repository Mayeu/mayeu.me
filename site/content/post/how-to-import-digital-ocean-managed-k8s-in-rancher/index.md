---
layout: post
title: "How to Import a Managed Digital Ocean Kubernetes cluster in Rancher"
category: blog
date: 2019-04-27
lang: en
---

*This post contains affiliate links to [Digital Ocean][DO]. It will get you
$100 to test out the platform, and if at some point you start using it for real
I will earn $25.*

[Digital ocean][DO] (DO) recently announced [their managed offering for
kubernetes][DO-blogpost].  Rancher is a tool that helps you manage multiple
Kubernetes clusters in one interface but it does not yet support the new DO
offering natively, and I was wondering if one could import a DO managed cluster
in your Rancher instance.

Turn out you can, here is how.

## TL;DR: just follow the importer

If you already know how to use the importer for existing clusters then you are
good to go. If not, just go there, chose the “Existing Cluster Import” option
and follow the steps to import your DO managed cluster 🙂

## Illustrated Guide

Here is a step by step guide on doing the import. It assumes you already have a
Rancher instance running somewhere. (Here is [a nice and straightforward guide
on running Rancher on
DO][rancher-tuto]).

* Your very first step is to go [create a managed cluster on DO][DO]. For that
  connect to your account, and in the sidebar select the “Kubernetes” menu.
  When there, follow the guide to create your cluster.

{{< img src="do-01-kubernetes-setup.png" >}}

* Now that your cluster is provisioning you can download its configuration. We
  are going to use it to connect to it via `kubectl`.

{{< img src="do-02-download-config.png" >}}

* Open your rancher interface, and click on the "Add Cluster" button

{{< img src="rancher-01-add-cluster.png" >}}

* Select the “Import existing cluster”

{{< img src="rancher-02-select-importer.png" >}}

* The importer will give you a `kubectl` command to run against your [Digital
  Ocean][DO] cluster. Use the previously downloaded config file to run it:

```
$ kubectl --kubeconfig=config-from-do.yml apply -f \
  https://your.rancher.domain/v3/import/lotofgibberishrlasxtowg.yaml
```

{{< img src="rancher-03-command-to-run.png" >}}
 
* When the configuration has been applied, your cluster should be imported and
  available in your rancher interface

{{< img src="rancher-04-cluster-imported.png" >}}

And voilà, you have imported a [Digital Ocean][DO] managed cluster in your
Rancher 🎉

[DO]: https://m.do.co/c/f1bcc66950f3
[DO-blogpost]: https://blog.digitalocean.com/digitalocean-releases-k8s-as-a-service/?refcode=f1bcc66950f3
[rancher-tuto]: https://www.digitalocean.com/community/tutorials/how-to-set-up-multi-node-deployments-with-rancher-2-1-kubernetes-and-docker-machine-on-ubuntu-18-04/?refcode=f1bcc66950f3
