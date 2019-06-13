---
title: "How to Read the Content of an External File With Ansible"
date: 2019-06-13
lang: en
---

Do you want to load up JSON data from a file directly into your Ansible
playbook, tasks or roles? Did you start by trying to read it via a `shell` or
command `module` and wondered if there was a better way? Well, there is, in the
form or `lookup` plugins. Read on to see how to use it.

Ansible comes with a whole bunch of [Lookup plugins][lp] that allow loading
stuff from the outside your play. The one we are interested in today is the
`file` [one][flp]. So, how do I load the content of my file with this?

Simply enough:

```yaml
vars:
  file_contents: "{{lookup('file', 'path/to/file.json')}}"
```

And bam, you have the content in the `file_contents` variable!

As you see, we are calling the `lookup()` function, to which we are passing the
plugin we want to use has the first argument (in that case `file`), and then
the path to our file. And just with that we loaded our file content!

**Note that the file must be on your Ansible controller** (i.e.: the computer
where you are running the `ansible` command).

You can directly use this in any module without the need for an intermediate
variable:

```yaml
- name: Read the content of a file instead of copying it directly
  copy:
    content: "{{lookup('file', 'path/to/file.json')}}"
    dest: /etc/config/file.json
```

And voilà 🙂

[lp]: https://docs.ansible.com/ansible/latest/plugins/lookup.html#plugin-list
[flp]: https://docs.ansible.com/ansible/latest/plugins/lookup/file.html
