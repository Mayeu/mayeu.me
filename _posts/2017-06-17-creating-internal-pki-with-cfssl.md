---
layout: post
title: "Creating an Internal Certificate Authority With cfssl"
category: blog
author: mayeu
tag:
- pki
- automation
---

## Overview
{:.no_toc}

* ToC
{:toc}

## Goals of This Article

In this article we are going to create a certificate authority (CA) using the
`cfssl` tool from CloudFlare. A certificate authority allows you to issue your
on X509 certificate used to secure communication via TLS. There is multiple
reasons that could lead you to create your own CA, in this case my goals is to
create and manage an internal CA for a small infrastructure (eg. a CA that will
only be used inside the infrastructure, and not shown to the rest of the
world).

This article covers:
- Creating a root CA that can only only have 2 intermediate CA in the chain (to
  only have one online CA)
- Creating intermediate CA that are dedicated to one role (one for web
  certificates, one for RabbitMQ certificates, etc.)
- Ensuring that the last intermediate CA of the chain can't create new CA

What is not covered by the article:
- Protecting your offline CAs, this is left as an exercise to the reader
- Automating or scripting the whole things, this may came in a later post
- Using an HSM
- Using cfssl as a web service

This article assume that you know your way to the command line interface

Let's dive in!

<div class="breaker"></div>

## What is a CA Chain?

<div style="float: right; text-align: center; margin: 20px;">
{% digraph simplest CA %}
node [shape=box]
rootca [label="Root CA"]
rootca
{% enddigraph %}
<figcaption class="caption">The simplest CA</figcaption>
</div>
This section covers some context and vocabulary we are going to use. If you are
well aware of how CA are working, you can jump directly to the [next
section](#creating-your-ca).

The simplest certificate authority we can have is only composed of the root
certificate, often called "Root CA".

As soon as we have this, we can issue a leaf certificate.
<div style="float: left; text-align: center; margin: 20px;">
{% digraph simplest CA issuing certs %}
node [shape=box]
rootca [label="Root CA"]
firstcert [label="A leaf\ncertificate"]
rootca -> firstcert
{% enddigraph %}
<figcaption class="caption">A Root CA issuing a leaf certificate</figcaption>
</div>

We call it a leaf certificate, because there will be nothing after it. Like the
leaf that end the tree.

This is our first certificate chain! The CA signs the leaf certificate. Thus
you have a chained formed by it. When a software get your certificate, it will
check if it knows the Root CA, and if it does, while check the chain between
your certificate and the root. In this case, the chain is direct.

So each time we want to create a new certificate, we have to use the root
certificate to sign our leaf certificate, so that our application are trusted.
That means that if we want to automatically create certificate, we are going to
need our root to be always available. That's why is called an online
certificate.

<div style="float: right; text-align: center; margin: 20px;">
{% digraph adding an intermediate CA %}
node [shape=box]
rootca [label="Offline Root CA"]
intermediateca [label="Online\nIntermediate CA"]
leafcert [label="A leaf\ncertificate"]
rootca -> intermediateca
intermediateca -> leafcert
{% enddigraph %}
<figcaption class="caption">Adding an intermediate CA</figcaption>
</div>
The issue here, is that if somebody access our Root CA, one can create a whole
bunch a certificate that are going to be trusted by our applications. The way
we solves that, is by creating an intermediate CA, which will sign our
certificates in the name of the root CA, while our root CA will be safely
offline.

Now our root CA is safe, away from the internet, and nobody can access it.

But we did not really solved the problem... What if someone get our
intermediate CA? One can still create any certificate trusted by any of our
application since we are still ultimately trusting one authority for all our
certificates!

<div style="float: left; text-align: center; margin: 20px;">
{% digraph splitting our intermediate CA %}
node [shape=box]
rootca [label="Offline Root CA"]
intermediatecaweb [label="Online\nIntermediate CA\nfor the Web"]
intermediatecarabbit [label="Online\nIntermediate CA\nfor RabbitMQ"]
leafcertweb [label="A leaf\ncertificate\nfor the Web"]
leafcertrabbit [label="A leaf\ncertificate\nfor RabbitMQ"]
rootca -> intermediatecaweb
rootca -> intermediatecarabbit
intermediatecaweb -> leafcertweb
intermediatecarabbit -> leafcertrabbit
{% enddigraph %}
<figcaption class="caption">Splitting our intermediate CA</figcaption>
</div>
So, let's create branches dedicated to one usage. In this example we are going to create:
- One branch that will only be trusted by our RabbitMQ clients and servers
- One branch that will only be trusted by our Web clients

With this setup, we can then ensure that not only one host could have all the
power to generate certificate. So if your RabbitMQ authority is compromised,
only this part of the application will be at risk, not the rest.

As a final touch, we can split our intermediate authority again, to have an
offline part, and an online one.

<div style="text-align:center">
{% digraph CA representation %}
node [shape=box]
rootca [label="Offline Root CA"]
intermediateweb1 [label="Offline\nIntermediate\nWeb"]
intermediateweb2 [label="Online\nIntermediate\nWeb"]
intermediaterabbitmq1 [label="Offline\nIntermediate\nRabbitMQ"]
intermediaterabbitmq2 [label="Online\nIntermediate\nRabbitMQ"]
rootca -> intermediateweb1
intermediateweb1 -> intermediateweb2
rootca -> intermediaterabbitmq1
intermediaterabbitmq1 -> intermediaterabbitmq2
{% enddigraph %}
<figcaption class="caption">Our final certificate authority</figcaption>
</div>

## Creating your CA

At the time I started writing this, I was using commit
[41f74f8](https://github.com/cloudflare/cfssl/tree/41f74f829982c84e29ec6e085c32c85a63163684)
of `cfssl`. Note that this commit is more advanced than the current
[1.2.0](https://github.com/cloudflare/cfssl/tree/1.2.0) version which won't
works with this article. Sadly there was not yet any official release since
this tag.

We are going to work in a dedicated folder:

```
mkdir our-ca
```

`cfssl` use has a main configuration file that contains our various CAs'
profiles. Let's first add our root CA configuration in this `cfssl-config.json`
file:

```json
{
  "signing": {
    "profiles": {
      "root-ca": {
        "key": {
          "algo": "ecdsa",
          "size": 256
        },
        "expiry": "43800h",
        "usages": [
          "cert sign",
          "crl sign"
        ]
      }
    }
  }
}
```

Here we defined a profile named `root-ca`, that uses shiny `ecdsa`
cryptographic key, and can only be valide for 5 year.

With the profile, we first need to create a *certificate signing request*, that
contains details about our CA. Again, with `cfssl` this file is a json file,
and in this example I called it `root-ca-csr.json`:

```json
{
    "ca": {
      "pathlen": 2
    },
    "CN": "Our root CA",
    "names": [
        {
            "C": "Our country",
            "ST": "Our state",
            "L": "Our city",
            "O": "Our organisation",
            "OU": "Our organisational unit"
        }
    ]
}
```

The `ca` hash represent again some CA specific configuration. Here, we make
sure our Root CA can only have a maximum of 2 intermediate CA under it. This
avoid creating chain that are more deep than planned originaly. For example if
one don't successfully access our last intermediate CA, but successfully create
a signing request for a new intermediate CA under the last one.

After that, `CN` is the common name of our certificate, here it's the name we
give to our root. In a web leaf certificate this is where you put the domain
you want to protect.

Finally the `names` array, contains the usual (and optional) data you can find
in a certificate. Fill it as you wish.

With both those file, we can create the CA with the following command:
```
$ cfssl gencert -config="cfssl-config.json" -profile="root-ca" \
              -initca root-ca-csr.json | cfssljson -bare root-ca
```

`cfssl` actually return a JSON structure, so to convert it into a normal
certificate we pipe the command into `cfssljson`. We use the `-bare` option
since we are not using cfssl through the HTTP API.

The command is self explicit enough, we use `cfssl` to generate a certificate
following the `root-ca` profile and the csr made for it, using the previously
made configuration, and since it's a certificate for a CA we use the `-initca`
option.

This command created the `root-ca-key.pem`, `root-ca.pem`, and the certificate
request `root-ca.csr`.

Using the `openssl` cli, you can see the details of your CA:
```
$ openssl x509 -in root-ca.pem -text
```

Now, ensure to secure your CA's key! You should encrypt it (out of scope for
this article), and keep it offline! Ideally you should have made this step on a
purelly offline computer.

## Creating a First (Offline) Intermediate CA

Let's add a new `intermediate-ca-1` profile in our `cfssl-config.json` just
after the `root-ca` one. This time we are going to use a ` max_path_len` of 1
since the root CA only allow a chain length of 2. Also it will only be capable
of signing crl and certs (be careful, the way the path len is define in the
intermediate certificate is not the same as with the root-ca, not sure if there
is any rational behind that, beside the fact that `cfssl` is in development):

```json
"intermediate-ca-1": {
  "expiry": "43800h",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "ca_constraint": {
    "is_ca": true,
    "max_path_len": 1
  },
  "usages": [
    "cert sign",
    "crl sign"
  ]
}
```

Again, we need to create a csr to generat the actual certificates. This time it
is called `intermediate-web-1-csr.json`, since it will be dedicated to our web
certificates:

```json
{
  "CN": "Our Web Intermediate CA 1",
  "names": [
    {
      "OU": "Web Dream Team"
    }
  ]
}
```

This time when we create the certificates, we define the `-ca` and `-ca-key`
option instead of the `-initca` one, that should point to our root CA
certificates & key. Otherwise our root won't be signing this intermediate CA.

```
$ cfssl gencert -ca root-ca.pem -ca-key root-ca-key.pem \
        -config="cfssl-config.json" -profile="intermediate-ca-1" \
        intermediate-web-1-csr.json |
  cfssljson -bare intermediate-web-1-ca
```

Again you can check the certificate with:
```
$ $ openssl x509 -in intermediate-web-1-ca.pem -text
```

And you'll see that this is a CA with a `max_path_len` of 1.

## Creating The Second Intermediate CA

The second intermediate CA will have almost the same configuration as the first
one.  The main change being that now `max_path_len` will be set to 0 (note that
we also need the option `max_path_len_zero` after that). Since this
intermediate CA is online, we are also going to use a shorter expiry time.

```json
"intermediate-ca-2": {
  "expiry": "8760h",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "ca_constraint": {
    "is_ca": true,
    "max_path_len": 0,
    "max_path_len_zero": true
  },
  "usages": [
    "cert sign",
    "crl sign"
  ]
}
```

Now our csr config `intermediate-web-2-csr.json`:

```json
{
  "CN": "Yourte Web Intermediate 2 CA",
  "names": [
    {
      "OU": "Web Dream Team"
    }
  ]
}
```

And again, we create the CA using the `cfssl` command line. This time, the
`-ca` and `-ca-key` should point to the first intermediate CA to continue the
chain:

```
$ cfssl gencert -ca intermediate-web-1-ca.pem \
        -ca-key intermediate-web-1-ca-key.pem -config="cfssl-config.json" \
        -profile="intermediate-ca-2" intermediate-web-2-csr.json |
  cfssljson -bare intermediate-web-2-ca
```

Again we can check the certificate with:

```
$ openssl x509 -in intermediate-2-web-ca.pem -text
```

And we'll see that this time the `max_path_len` will be  0, so we won't be able
to create another CA using this one.

## Creating a Leaf Certificate With Your CA Chains

For our leaf certificate we are going to use `rsa` as a crypto algo as it is
more supported out there. The main change from the previous profile is the
usages that only allow `server auth`, so we can only create certificate that
authentify servers. We also reduce the max lifetime to 90 days.

```json
"web-leaf": {
  "ca_constraint": {
    "is_ca": false
  },
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "usages": [
    "server auth"
  ],
  "expiry": "2160h"
}
```

This profile contain the common data of all our leaf certificates. Now we can
create a csr for one of those certificate:

```json
{
    "CN": "admin.our-web.net",
    "hosts": [
      "admin.our-web.ch"
    ],
    "names": [
        {
            "OU": "A Web Service"
        }
    ]
}
```

And we can generate it using the second intermediate CA:
```
$ cfssl gencert -ca intermediate-web-2-ca.pem \
        -ca-key intermediate-web-2-ca-key.pem -config="cfssl-config.json" \
        -profile="web-leaf" admin.our-web.net.json |
  cfssljson -bare admin.our-web.net
```

As always we can check the certificate via:
```
$ openssl x509 -in admin.ma-yourte.net.pem -text
```

## What do we have now, and what can we do next?

Until now we created only one chains, and as you see we use "web" everywhere to
make it tacitly a certificate authority to authenticate the HTTPS protocol. Now
we can create another chain for other purpose, for example for a VPN, RabbitMQ,
or other tools that need encryption to protect communication.

This segmentation by intermediate certificate chain helps you to ensure that a
certificate for one usage is not used for another. For example, your VPN will
only recognize one chain, so somebody putting its hand on a web certificate
will not be able to connect to the VPN. You could also repudiate a full chain
at once in case your online CA get hacked.

Now you can automate your certificate creation via multiple mean:
- cfssl can run in server mode in an host
- You can use your usual configuration management tool (like Ansible or Puppet)
  to run the needed command and distribute the files
- Vault could be use to generate certs on the fly when needed

## References

- [Intermediate CA config](https://gist.github.com/riyad/e9dd6e688ea5de69a65a)
- [How to Generate a Self-Signed Root Certificate with CF-SSL](https://fernandobarillas.com/blog/2015/07/22/how-to-generate-a-self-signed-root-certificate-with-cf-ssl/)
- [Creating an Intermediate CA for MITMProxy](https://fernandobarillas.com/blog/2015/08/06/creating-an-intermediate-ca-for-mitmproxy/)
- [cfssl doc](https://github.com/cloudflare/cfssl/blob/master/doc/cmd/cfssl.txt)
- [pathLenConstraint question on SO](https://stackoverflow.com/questions/6616470/certificates-basic-constraints-path-length#6617814)
- [How to build your own public key infrastructure](https://blog.cloudflare.com/how-to-build-your-own-public-key-infrastructure/)

