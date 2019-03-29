---
layout: post
title: "How to backup Hashicorp Vault"
category: blog
ref: vault-backup-and-restore
lang: en
draft: yes
---

# Let's backup and restore vault.

First, let's create a test environment for this:

```
$ mkdir vault-backup
```

Let's add a requirements.yml:

```
- src: brianshumate.consul
  name: consul

- src: brianshumate.vault
  name: vault
```

A playbook name site.yml:

```
---
- hosts: all
  gather_facts: False
  become: yes

  tasks:
  - name: install python
    raw: test -e /usr/bin/python || (apt -y update && apt install -y python-minimal)

- hosts: all
  become: yes
  become_user: root
  vars:
    - vault_iface: enp0s8
    - consul_bootstrap_expect: true
    - consul_node_role: 'server'
  roles:
    - consul
    - vault
```

And finally a vagrant file:

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define :vault_original do |config|
    config.vm.box = "ubuntu/xenial64"
    config.vm.network :private_network, ip: "10.1.42.42"
    config.vm.hostname = "vault-original"
  end

  config.vm.provision :ansible do |ansible|
    ansible.playbook = "site.yml"
    ansible.limit = "all"
    ansible.groups = {
      'vault_instances' => [:vault_original],
      'consul_instances' => [:vault_original]
    }
  end
end
```

Now let's run everything:

```
$ vagrant up
```

OK, we have all that setup, let's initialise vault:

```
$ export VAULT_ADDR=http://10.1.42.42:8200
$ vault init
```

Now we have the unseal keys, and the initial root token.

```
Unseal Key 1: /Y4V2/do1p2VVHufcWSZKFw0PDQGiL5llgOBDKhym8h5
Unseal Key 2: wGHvc5S5iKw8Ey9owZhuOs5+6QAwQ9SAoD6b0yKefyvB
Unseal Key 3: vu5M2Fhy8F2mawrMt6yVcF72e0qLUwMORyX+7WpLV2Fh
Unseal Key 4: 0tUaOAzlHEREjWeO0GnBokvj7t2MNCaJfSMiSIWnIs9x
Unseal Key 5: hHTMLtCWJvnekOi36ioAi5RisRGv9/I39C15dYAszU+M
Initial Root Token: 873e4848-0bec-8ba9-6b37-f13cdcfe9c07
```

We can unseal (repeat this commande three time untill the vault is unsealed):

```
$ vault unseal
```

Let's add some sikret now:

```
# DON'T USE THE ROOT TOKEN IN PRODUCTION!
$ export VAULT_TOKEN=873e4848-0bec-8ba9-6b37-f13cdcfe9c07
$ vault mount kv
$ vault write kv/api_token/exoscale api_secret=supersikret
$ vault read kv/api_token/exoscale
```

Yeay, we has a sikret!

Now, let's dump the consul state:

```
$ consul snapshot save /vagrant/consul-state-`date -I`
```

boom, backup. Vault store sikret encrypted in consul, so you may not need to encrypt this file again. But why not?

Ok, now let's create a new server, and try to load this file!

```
$ vagrant down vault_original
$ vagrant up new_vault
```

Let's restore our consul snapshot:

```
$ vagrant ssh new_vault
$ consul snapshot restore /vagrant/consul-state-`date -I`
```

Now, let's check vault:

```
$ export VAULT_ADDR=http://10.1.42.24:8200
$ vault status
Type: shamir
Sealed: true
Key Shares: 5
Key Threshold: 3
Unseal Progress: 0
Unseal Nonce: 
Version: 0.9.0

High-Availability Enabled: true
        Mode: sealed
```

Looking good! we have an existing vault, and we did not had to init it, let's unseal and check our previous password:

```
$ vault unseal # 3 times
$ export VAULT_TOKEN=873e4848-0bec-8ba9-6b37-f13cdcfe9c07
$ vault read kv/api_token/exoscale                       
Key                     Value
---                     -----
refresh_interval        768h0m0s
api_secret              supersikret
```

And voilà. We have our stuff back.

I don't know if it is still the case, but on previous Vault & Consul version you could
end-up with a vault server in standby mode. This was due to the
[`vault/core/lock` key in consul still referencing the previous vault
server](https://groups.google.com/d/msg/vault-tool/kEPvBTpAqh4/tkiwRmXrBwAJ).
If you end up in this situation, you can try to delete the key:

```
$ consul kv delete vault/core/lock
```

And then your vault server will re-lock and be active.
