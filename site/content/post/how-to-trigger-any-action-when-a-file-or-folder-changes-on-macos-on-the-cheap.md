---
title: "How to Trigger Any Action When a File or Folder Changes on Macos on the Cheap"
date: 2019-04-11
layout: post
lang: en
category: blog
---

Did you ever want to trigger an action when a file changed? For example, automatically move a file that has just been downloaded? The action could be a script, app, anything really. Here I will describe how to do exactly that on macOS with only the tools provided by the default system.

*Side note: I know there are GUI app that does that in a much simpler manner; here I just want to highlight how to do that manually with what macOS is providing to us.*

But before we start, I would like to stress the fact that this method may not be ideal for anything critical to take place. Quoting the docs:

> ⚠️ IMPORTANT: Use of this key is highly discouraged, as filesystem event monitoring is highly race-prone, and it is entirely possible for modifications to be missed. When modifications are caught, there is no guarantee that the file will be in a consistent state when the job is launched.    

This basically means that:

- if there is too much change happening at once, some may be missed and your action won’t trigger
- You can’t be sure that your action will find the file in the exact state that triggered the script

But I believe that for day-to-day workflows, which are not computationally demanding, those caveats are not really a problem.

# How to watch for changes?

For this we will be using `launchd` which is  [the service manager running on macOS](https://en.wikipedia.org/wiki/Launchd).  It has two main tasks:

- Booting the system
- Managing daemon and agents

In `launchd` lingo, an agent is a service run on a per user basis, and a daemon is a system service.

`launchd` has multiple levels of configurations, some are system-wide and privileged, but you can also use it to run unprivileged user tasks. There are five folders in which you can find those definitions:

* `~/Library/LaunchAgents`: per user agents provided by the user.
* `/Library/LaunchAgents`: per user agents provided by the administrator.
* `/Library/LaunchDaemons`: systemwide daemons provided by the administrator.
* `/System/Library/LaunchAgents`: per user agents provided by Apple.
* `/System/Library/LaunchDaemons`: systemwide daemons provided by Apple.

In our case, we will be using a small `launchd` agent that is going to be stored in `~/Library/LaunchAgents`. We will see later on how we can load or unload our agent to active or deactivate it.

# The test Setup

Let’s get some action going on, hop in your terminal and go to a clean folder for our test. From here I will assume that the folder you are using is `~/file-watching-test`, if you are using another one don’t forget to adapt your paths in the rest of the article!
```
$ mkdir ~/file-watching-test
$ cd ~/file-watching-test
```

In this folder we are going to create an empty `watched` file that will be monitored by `launchd`:
```
$ touch ~/file-watching-test/watched
```

We are also going to create the script that will be called when the watched file changes, open the `~/file-watching-test/script.sh` file in your favourite editor and add:
```
#!/bin/sh
echo "$(date): 🐈 I has be summoned" >> ~/file-watching-test/result
```

Let’s break out what is happening here:

- `echo "$(date): 🐈 I has be summoned"`: 
	- this echo command will get the return of the date command executed via `$()` 
	- print `<current date>: 🐈 I has be summoned` to the standard output. 

You can try it directly in your shell to see what is happening. Then:

- `>>`: this is a redirection operator. This one takes whatever has been printed on the standard output (so not the errors, if any) and **append** it to the file it points toward. With this we can log all the execution of our script.
- And finally,  `~/file-watching-test/result` is our result file that will receive the output of our `echo` command.

Now, make sure the script can be executed with `chmod +x ~/file-watching-test/script.sh`.

To sum up, we have the following hierarchy:
```
$ tree file-watching-test
file-watching-test
├── script.sh      # Our script
├── watched        # The file we are watching
```

# Creating a service file for `launchd`

We want our test service to:
* Watch the `~/file-watching-test/watched` file
* When a change happens, we want to execute `~/file-watching-test/script.sh`

Before I show you the service file, be warned that `launchd` use XML for service declaration, so brace yourself.

Here is our `me.mayeu.watchtest.plist` file:
```xml
<?xml version=“1.0” encoding=“UTF-8”?>
<!DOCTYPE plist PUBLIC “-//Apple//DTD PLIST 1.0//EN” “http://www.apple.com/DTDs/PropertyList-1.0.dtd”>
<plist version=“1.0”>
<dict>
        <key>Label</key>
        <string>me.mayeu.watchtest</string>
        <key>ProgramArguments</key>
        <array>
                <string>/Users/m/file-watching-test/script.sh</string>
        </array>
        <key>WatchPaths</key>
        <array>
                <string>/Users/m/file-watching-test/watched</string>
        </array>
</dict>
</plist>
```

OK let’s break that down, and be sure to adapt the various paths to the one you are using! If you are unsure, use the `pwd` command in your shell when you are in the `file-watching-test` folder to print absolute path of the folder.

The very first part is not really interesting since it is a declaration of the format and the document type definition (DTD):
```xml
<?xml version=“1.0” encoding=“UTF-8”?>
<!DOCTYPE plist PUBLIC “-//Apple//DTD PLIST 1.0//EN” “http://www.apple.com/DTDs/PropertyList-1.0.dtd”>
```

Then, we state that the file is using the `plist` format version 1.0. A `plist` is the named used for `Property List` files that are use to store configuration, services, serialised objects and more in macOS. We also declare that this `plist` contains a dictionary (`dict`):

```xml
<plist version=“1.0”>
<dict>
...
</dict>
</plist>
```

Inside those key we are going to declare our job. First, we have to provide a unique label to identify the job. Here I use `me.mayeu.watchtest`:
```xml
<key>Label</key>
<string>me.mayeu.watchtest</string>
```

By convention (not only but we don’t need to dive to deep in this), one uses the reversed domain following by some name representing the app. This ID is also used to identify the application and other related resources.

For example, Evernote uses `com.evernote.Evernote` as an application ID.

Then, we declare the program we are going to run using the `ProgramArguments` key:
```xml
<key>ProgramArguments</key>
<array>
    <string>/Users/m/file-watching-test/script.sh</string>
</array>
```

This key take an array listing all the arguments. In our case it is just the path to the script, but if we wanted to execute `git commit -m “My commit message”` we would do this like:
```xml
<key>ProgramArguments</key>
<array>
    <string>/usr/bin/git</string>
    <string>commit</string>
    <string>-m</string>
    <string>My commit message</string>
</array>
```

And finally, we declare when to run the program, in that case we use the `WatchPaths` key that take an array of paths to watch:
```xml
 <key>WatchPaths</key>
 <array>
    <string>/Users/m/file-watching-test/watched</string>
 </array>
```

Done! We have our new service.

If you are curious of what `launchd` can do, you can find all the valid key detailed in the `launchd.plist` manpage: `man 5 launchd.plist`. `launchd` should also be used for time-based jobs instead of using `cron`. See [the Apple documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/ScheduledJobs.html#//apple_ref/doc/uid/10000172i-CH1-SW2) for more about that.

# Trigger it!

Almost there! We have all the pieces we need so let’s copy our service file to the right place:
```
$ cp me.mayeu.watchtest ~/Library/LaunchAgents/
```

We will now tell `launchd` to load it:
```
$ launchctl load ~/Library/LaunchAgents/me.mayeu.watchtest
```

Now that `launchd` has loaded our service, we can change our watched file by adding content in it:
```
$ echo ‘trigger the watcher’ > test/watched`
```

And this should have triggered the script; thus we will have some content in the result file:
```
$ cat ~/file-watching-test/result
Thu Apr 11 12:39:41 +07 2019: 🐈 I has be summoned
```

🎉

If we trigger it again, we should see a new line:
```
$ echo ‘trigger the watcher’ > test/watched`
$ cat ~/file-watching-test/result
Thu Apr 11 12:39:41 +07 2019: 🐈 I has be summoned
Thu Apr 11 12:42:55 +07 2019: 🐈 I has be summoned
```

We are done with this test! To clean behind ourselves we are going to:
- unload the service
- delete the service `plist`
- delete our test folder

```
$ launchctl unload ~/Library/LaunchAgents/me.mayeu.watchtest
$ rm -rf ~/Library/LaunchAgents/me.mayeu.watchtest
$ rm -rf ~/file-watching-test
```

This is it! You now have some basis on using `launchd`, and maybe you learned one or two things about your shell and shell scripts at the same times 🙂

One last point, you can also watch folders using this method and thus act on any changes that happen under those folders, may it be deleted files, new files, new folders, etc.

Have fun! And if you build something cool with this, do not hesitate to poke me about this on [Twitter](https://twitter.com/Mayeu) or by email: **m [-at-] mayeu [-dot-] me**.
