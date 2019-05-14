---
title: "Fix Typo in Shell Commands Easily With Fc"
date: 2019-05-13
draft: false
lang: en
category: randombytes
---

From time to time, it can be quite cumbersome to fix a mistyped command in your
shell. What if you could fix the command you just typed in your favourite
editor? Well, that’s exactly what `fc` command is all about, and it is standard
to all Unix system (this includes GNU/Linux & macOS). Let see how that work.

From Wikipedia:

> **fc** is a standard program on Unix that lists, edits and reexecutes
> commands previously entered to an interactive shell.

Using `fc` looks something like this:

1. You type a non-working/wrong command
2. You type `fc`
3. The last typed command (before `fc`) is open in your editor
4. You fix the command, save, and quit
5. When you exit the editor, the edited command is executed

Here is an interactive example in which I use the wrong path and fix it via fc:
<script id="asciicast-245863" src="https://asciinema.org/a/245863.js"
async></script>

Of course this example is a little bit contrived because you should use
autocompletion to navigate folders and not type your path entirely.

Checking my history, I have found this big command (which check if Homebrew’s
ZSH path is part of the `/etc/shells` file):

```
export zshpath="$(brew --prefix)/bin/zsh"; \
grep -q "^${zshpath}" /ec/shells || \
sudo -E sh -c "echo '$zshpath' >> /etc/shells"
```

It is not obvious, but there is a mistake right in the middle: `/ec/shells`
instead of `/etc/shells`. With `fc` fixing this is really easy to fix since I
will have access to my whole editor and not only my shell movement and
shortcut.

But that’s not all `fc` can also take an argument to fix an arbitrary command
from your shell history, not only the last one.

Use `fc -l` to list your history

```
$ fc -l
 6213  rm -rf test
 6214  brew install asciinema
 6215  vim ~/bin/mac-bootstrap
 6216  exit
 6221  ls
 6222  mkdir right-path
 6228  asciinema rec
 6229  cd wrong-path
 6230  fc
 6231  cd right-path
 6232  pwd
```

Then you can use `fc <history number>` to fix a specific command:

```
$ fc 6214
# Will open “brew install asciinema” in your editor
```

There is not much more to this tool, but you can find the full documentation
[of fc
here](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/fc.html) if
want to check out the other arguments.
