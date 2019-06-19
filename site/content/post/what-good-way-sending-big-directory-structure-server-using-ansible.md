---
title: "What's a good way of sending a big directory structure to a server using Ansible?"
date: 2019-06-19
lang: en
---

Ansible has a `copy` module that works really well for moving a small set of
files around. But it can rapidly slow down your playbook since [it does not
scale well with hundreds of files][cm]. So how can you move a big set of files
and folder without losing too much time? Well, you use another module named
`synchronize` for this.

`synchronize` uses a tool named `rsync` under the hood, so you first have to
ensure it is installed on your machine, and on the targeted host (it comes with
most Unixes). If you are using macOS or Ubuntu, it should be already there.
Otherwise start by installing it on your computer.

To be sure it is installed on your targeted server you should add a task to
install it before you use the `synchronize` module in your playbook. Here it is
an example for Ubuntu or Debian hosts:

```yaml
- name: Install rsync running synchronize later
  apt:
    name: rsync
    state: present
```

By default `synchronize` just require a `src` and a `dest`, but like a lot of
Ansible modules [there are many more options for finer control][sm].

Here is a minimal example of using the module:

```yaml
- name: Synchronize a local folder to my remote server
  synchronize:
    src: path/to/my/local/folder
    dest: /absolute/path/to/my/destination/folder
```

And with that you can copy a gazillion files (at least) without worrying that
your copy will be slow!

Happy syncing 👋

[cm]: https://docs.ansible.com/ansible/latest/modules/copy_module.html#notes
[sm]: https://docs.ansible.com/ansible/latest/modules/synchronize_module.html#synchronize-module
