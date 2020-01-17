---
title: "Easy things you can do to speed up ansible"
date: 2020-01-17
lang: en
---

Maybe you are using Ansible for some time and your playbooks have grown big enough to take a lot of time? Or maybe you are just trying it out and it feels already too slow for your taste? Whatever the reason, you may be wondering if there are quick changes you can do to speed things up a bit, so here are small modifications you can do right now to reclaim a bit of your time.

## Connection parallelism
If you are targeting more than one server with your playbook, the very first thing to do is to make sure Ansible connects to multiples of them at the same time. For that, you are going to set how many `forks`  are going to run concurrently.

You can either configure that in your `ansible.cfg` file: 
```ini
[defaults]
forks = 10
```

Or pass the `--forks 10`  option to the `ansible-playbook` command.

Or even set it via the environment: `ANSIBLE_FORKS=10`.

Whatever solution you choose, the point is to run Ansible on as many servers as possible at the same time. The only limit is your control host performance, the more connection running concurrently there is, the more resource is going to be consumed.

And if it happens that you really need to run a part of your playbook in a serial fashion, then you can use the `serial` keyword for that. Like this:
``` yaml
- host: all
  serial: 1     # To only run on one host at a time
  serial: 3     # or 3 at a time?
  serial: "16%" # or maybe 16% of my server at a time?
```

## Limit Fact Gathering to a minimum
By default, Ansible will gather facts about all the machines you are deploying to at the beginning of each playbook. Even if you don’t really use those facts afterward.

If you know your play don’t use the fact automatically collected by Ansible, you can disable it on a playbook by playbook basis:
```yaml
- host: all
  gather_facts: False
```

Alternatively, you can reverse the default behaviour so that you need to explicitly ask to gather facts in your playbook. This can be achieved by adding the following in your `ansible.cfg` file:
```ini
[defaults]
gathering = explicit
```

Then when you need those facts you will need to explicitly ask for them in your playbook:
```yaml
- host: all
  gather_facts: True
```

Finally, you may not know if you really need those facts, or you really don’t plan to go back to check all your playbooks and roles to see if it is the case. If that’s you, then use the `smart` option in your `ansible.cfg`:
```ini
[defaults]
gathering = smart
```

Now Ansible will only gather the facts the first time it connects to a new host during the run, and not anymore during that run.

## Activate SSH Pipelining

The pipelining option reduce the number of SSH operations Ansible does in order to execute a task on the target host. Activating this option can significantly improve the runtime performance of your playbook.

You can activate it in your `ansible.cfg` with:
```ini
[ssh_connection]
pipelining = True
```

And, if everything work, that’s perfect, enjoy 👍.

But maybe after turning that on you get some weird `sudo: no tty present` error when you run your playbook? If so, you should modify the `sudoers` file on your targets. Add the following playbook to be run before anything else: 

⚠️  _This play modifies the `/etc/sudoers` file, **which is critical for `sudo` to work**. Breaking this file could prevent you from getting root access on your host. **Run this on a test host** before running it in your production environment to ensure it works_ ⚠️ 
```yaml
- hosts: all
  vars:
    ansible_ssh_pipelining: no
  tasks:
    - name: Enable ansible pipelining
      lineinfile:
        regexp: ‘^\w+\s+requiretty’
        dest: /etc/sudoers
        state: absent
      tags:
        - enable_pipelining
```

This should ensure you won’t see the previous error. Some consider this `requiretty` a security mechanism, but [other don’t](https://unix.stackexchange.com/questions/65774/is-it-okay-to-disable-requiretty).

## Limiting Fact Gathering Even More
OK with all that you should have had a speed boost already. But maybe running one fact gathering each time you are running your playbook is already too much for you, and your facts don’t really change much anyway.

This is when caching the facts comes in. You can configure Ansible to run the fact gathering and then cache them for a day, 12 hours, a week, whatever match your use case.

Let’s modify your `ansible.cfg` again to activate caching (only work with `smart` or `explicit` fact gathering):
```ini
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = ./.facts
fact_caching_timeout = 86400
```
And now your facts are cached for 1 day. Nice.

Here we are using a JSON file as cache, but there are other fancy plugins, like using [a yaml file](https://docs.ansible.com/ansible/latest/plugins/cache/yaml.html), or maybe [redis](https://docs.ansible.com/ansible/latest/plugins/cache/redis.html)? Check the [cache plugins documentation](https://docs.ansible.com/ansible/latest/plugins/cache.html) for more examples.

## Finally
And if after all that running the playbook is still too slow, you can gather more metrics about your playbook by using two [callback plugins](https://docs.ansible.com/ansible/latest/plugins/callback.html#plugin-list):

- the  [profile_tasks](https://docs.ansible.com/ansible/latest/plugins/callback/profile_tasks.html) plugin
- and the [timer](https://docs.ansible.com/ansible/latest/plugins/callback/timer.html)  plugin

A callback plugin is a plugin that changes how Ansible respond to some internal events, and control the output of the running command.

Those can be activated by adding the following in your `ansible.cfg`:
```ini
[defaults]
callback_whitelist = profile_tasks, timer
```

As you may guess from the name, the `profile_tasks`  plugin adds timing data to each task, while the  `timer`  one shows the runtime of the full play.

And if even after all those changes, you still feel that your playbook is slow, then you may want to [take a look at Mitogen](https://networkgenomics.com/ansible/), which basically swap the Ansible engine for a new one that reduces execution time drastically. But you’ll have to explore that by yourself 😉

