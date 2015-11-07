---
layout: post
title:  NixOS, laptop sleep, and systemd
categories: nixos
---

During quite a long time, I was putting my laptop in sleep mode by
manually calling (or researching in the history), a small script that
was:

- invoking my lock screen (i3lock)
- sleeping a couple of second
- invoking `systemctl suspend`

While this worked, I wanted to be able to use the dedicated key, or
to simply shut the lid to put my laptop to sleep, with a lock screen.
Note that suspending worked out of the box with the key, but not the
lid; and in both case, without lock screen.

Small detail of my setup:

- Laptop: Asus UX301LA
- OS: [NixOS 15.09](https://nixos.org/) (at the time of writing)
- WM: [i3](http://i3wm.org/)
- [TLP](http://linrunner.de/en/tlp/tlp.html) for power management.

All the modifications are done in `/etc/nixos/configuration.nix`. Obviously this will depend of your personal organisation.

So, first things first, I force the desktop manager to drop its grasp on the lid and power:

{% highlight nix %}
# Prevent the display manager to take over the lid
services.xserver.displayManager.desktopManagerHandlesLidAndPower = false ;
{% endhighlight %}

*Note that with i3 this may not be needed, also the default settings is false now. But I prefer to be explicite here.*

Then, I configure logind to always suspend when I close the lid:
{% highlight nix %}
services.logind.extraConfig = ''
  HandleLidSwitch=suspend
  HandleLidSwitchDocked=suspend
'';
{% endhighlight %}

Now, we have to create a suspend@ service for systemd. As everything with NixOS, you use the [NixOS options](https://nixos.org/nixos/options.html) for that, you don't directly write a service file:

{% highlight nix linenos %}
systemd.services.suspend = {
  description = "User suspend actions";
  before = ["sleep.target"];
  environment = { DISPLAY = ":0.0"; };
  script = "${pkgs.i3lock}/bin/i3lock -d -c 0c0c0c";
  postStart = "${pkgs.coreutils}/bin/sleep 1";
  wantedBy = ["sleep.target"];
  serviceConfig = {
    User = "m";
    Type = "forking";
  };
  enable = true;
};
{% endhighlight %}

*This is an adaptation of the «[Sleep hooks](https://wiki.archlinux.org/index.php/Power_management#Sleep_hooks)» section in the [Archlinux wiki](https://wiki.archlinux.org/).*

For comparaison, here is the equivalent service file:
{% highlight ini linenos %}
[Unit]
Description=User suspend actions
Before=sleep.target

[Service]
User=m
Type=forking
Environment=DISPLAY=:0.0
ExecStart=/path/to/i3lock -d -c 0c0c0c
ExecStartPost=/path/to/sleep 1

[Install]
WantedBy=sleep.target
{% endhighlight %}

As you can see, it mostly a 1:1 translation in nix language.

Here is a details of the Nix specific bits, the first thing to do, is
to declare a new service name suspend:

{% highlight nix %}
systemd.services.suspend = { } ;
{% endhighlight %}

Most of the field have a equivalent in the NixOS options, and you simply have to find the fields in the documentation no now what type of data is expected by nix (list, set, string,...).

The `User` and `Type` don't have associated nix options, so you have
to use the `serviceConfig` option that allow you to use/create any
field that don't have a direct equivalence in nix (there is also a `unitConfig` for the unit part of the service):

{% highlight nix %}
serviceConfig = {
  User = "m";
  Type = "forking";
};
{% endhighlight %}

Finally, because of the way the [Nix store is made](https://nixos.org/nixos/about.html), it is impractical to directly put the path of the binary in the action. For instance, right now here is my local path to i3lock and sleep:

<div class="highlight"><pre><code>
/nix/store/4q9fzdwfxbq4wd6npfdr4mj9jk8fl28y-i3lock-2.6/bin/i3lock
/nix/store/qawmaicxcljwd25gsq9dqbw7c3q7hjmi-coreutils-8.24/bin/sleep
</code></pre></div>

Also, those path will change at any upgrade of the package, so you
want to use `${pkgs.<pkg_name>}` instead, with this you are always
sure the path is the good one, and that it exist in the nix store (yes, that mean that Nix will instead the package if needed):

{% highlight nix %}
script = "${pkgs.i3lock}/bin/i3lock -d -c 0c0c0c";
postStart = "${pkgs.coreutils}/bin/sleep 1";
{% endhighlight %}

Finally, rebuild and switch to your new system with `sudo nixos-rebuild switch`, and you'll have i3lock launching before your laptop goes in suspend mode :).
