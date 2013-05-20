---
title: 'Getting your e-mail out of the cloud, part 1: Postfix'
date: 2013-02-21
published: false
tags: cloud, howto
---

I recently wanted to get out of Gmail and finally set up my e-mail server.
After some day fighting my way through Postfix, Dovecot and others, I finally
got it up and running.

Since I had to get all the info from multiple sources and documentation, I
decided to write some articles describing the process and what I understood :)

This articles will be a serie of articles describing different part of the
e-mail server. At this time there is 4 parts planned:

* [Part 1: Postfix](#)
* Part 2: Dovecot
* Part 3: Your e-mails are spam
* Part 4: Avoiding spam in your e-mail

## What will be set up
{:.no_toc}

First of all, my goal is not about serving e-mail to thousand of customers, or
providing e-mail service to other peoples than me. So I wanted to keep it
simple, no DBMS (seriously, a DBMS to handle 5 e-mail addresses?
SERIOUSLY?[^seriously]), everything in flat file, the minimum of configuration,
the minimum of softwares, no webmail (for now at least, but I am pretty sure it
much more simpler to setup a webmail software than it is to setup Postfix).

My server run Debian 6 GNU/Linux, so this little guide is made with Debian in
mind, but I am sure it can be pretty easily ported to any other GNU/Linux, or
even \*nix.

There is what I choose to setup and play with:

* Postfix: to handle SMTP, and receiving the mail.
* Dovecot: to handle IMAP. This protocol may not be a good choice if your e-mails are sensible.
* Virutal e-mail account: e-mail account are not linked to actual GNU/Linux account.
* Maildir format.
* Flat file for frak sake.
* Anti-spam thingie (in a near futur)

## What will NOT be set up
{:.no_toc}

I do not plan to teach you GNU/Linux or to administrate Debian. You should have
some (small) knowledge of the \*nix you plan to use, and of the glorious
command line. I will not explain to you the whole client part to send and get
your mail.

You will have to setup your DNS alone (there is only the MX field to set).

And finally, this is not a short article with a copy-this-conf-and-voilà style.
First because this generaly do not work, and second, because if something break
later you will have no idea of what is the problem.

# Part 1: Postfix

Let's start with the Postfix configuration:)

* toc
{:toc}


## Dafuq is Postfix?

<figure>
<img src="img/mysza.gif">
   <figcaption>
      <p><small>Postfix illustrated.</small></p>
   </figcaption>
</figure>


Postfix is a MTA, meaning that its role is to send mail (from the local
machine), transfer e-mail received by SMTP to an other SMTP server, and put the
e-mail you receive in a folder (in mailbox or maildir format and maybe other
format).

As you see there is no IMAP/POP involved, so no way to get your e-mail back.
That is because it is the role of Dovecot, not Postfix.

Also, Postfix does not integrate a authentication mecanism. In our case, we
will setup SMTP authentication using Dovecot (Postfix will simply forward the
auth data to the account setup in Dovecot.)

## Basic configuration

So, you just installed Postfix -- in Debian you can choose the `Internet host`
configuration during install, it will add most of the needed configuration --.
If you look in the folder `/etc/postfix` you will see various configuration
file. The most (and only) interesting one for us is `main.cfg`.

With the default configuration you should already be able to send e-mail using the `mail` command :

~~~
$ mail dest@domain
~~~

That's cool, but not really usefull, let's start the modification of
`/etc/postfix/main.cfg`.

### Hostname, domain, origin and destination

Easy options, `myhostname`[^postfix_myhostname] is the hostname of your server,
and `mydomain`[^postfix_mydomain] is the domain we will use in the mail. Next,
we setup `myorigin`[^postfix_myorigin]  which is basically the domain which the
mail will come from, in our case, it will be `$mydomain`.

Finally, `mydestination`[^postfix_mydestination] contains the list of domain
delivered by the local transport of postfix. So it should basically contains
the hostname of your server. The default value should be good and enough. (If
later on your e-mail are rejected with an error like this:

~~~
550 5.1.1 <m@6x9.fr>: Recipient address rejected: User unknown in local recipient table
~~~

It may be because you have a problem with this option).

In my case that gives me the following value:

~~~
# Hostname, domain, origin and destination
mydomain      = 6x9.fr
myhostname    = mail.$mydomain
myorigin      = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost
~~~

### Network

The `inet_interfaces`[^postfix_inet_interfaces] allow you to choose on which
interfaces you will receive your mail. The default value is `all`, and that the
value I have personally enforced. You also have the
`mynetworks`[^postfix_mynetworks] option to set. The default value correspond
to your local machine, and it is fine this way (This value correspond to the
trusted ip that have more privileges in SMTP).

We will leave the `relayhost`[^postfix_relayhost] blank, we do not need it
since we will only do local transport.

~~~
inet_interfaces = all
mynetworks      =  127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/126
relayhost       =
~~~

### Other values

I set the `mailbox_size_limit`[^postfix_mailbox_size_limit] to `0`, because I
am alone on this server, so no limit.

<figure>
<img src="img/remove_all_the_limit.jpg">
   <figcaption>
      <p><small><code>mailbox_size_limit = 0</code> illustrated.</small></p>
   </figcaption>
</figure>

And you should let the default value for
`recipient_delimiter`[^postfix_recipient_delimiter] (unless you wish others
symboles for delemiter).

~~~
# Other
mailbox_size_limit  = 0
recipient_delimiter = +
~~~

### Avoiding being an open relay

We want to avoid being an [open relay][open_relay], that is not a good idea,
unless you want your server being flagged as spammers.

By default we should not be an open relay, but we can test this pretty easily.
Go on your box, and contact through telnet the following server :

~~~
$ telnet rt.njabl.org 2500
~~~

This will contact [njabl.org](http://njabl.org/) which will test if your server
is an open relay or not. You should see something like this:

~~~
...
>>> MAIL FROM:<relaytestsend@rt.njabl.org>
<<< 250 2.1.0 Ok
>>> RCPT TO:<relaytest%rr.njabl.org@>
<<< 554 5.7.1 <relaytest%rr.njabl.org@>: Relay access denied
>>> RSET
<<< 250 2.0.0 Ok
>>> MAIL FROM:<relaytestsend@mail.6x9.fr>
<<< 250 2.1.0 Ok
>>> RCPT TO:<relaytest%rr.njabl.org@mail.6x9.fr>
<<< 554 5.7.1 <relaytest%rr.njabl.org@mail.6x9.fr>: Relay access denied
Can't relay 
~~~

Carefully read the result to check that you *can not* relay e-mail, unless you
did something really wrong in the previously seen configuration, you should not
be able to relay e-mail.

<figure>
<img src="img/relaying_is_bad.jpg">
   <figcaption>
      <p><small>Open relay illustrated.</small></p>
   </figcaption>
</figure>

### Test e-mail

If you wish you can send a mail again from your server:

~~~
mail dest@domain
~~~

You should now see the good origin in the mail from address.

## Virtual e-mails

First we need to define the domains that will have virtual e-mail using
`virtual_mailboxdomains`[^postfix_virtual_mailboxdomains], this option contains
the list of domain Postfix will accept as final destination. So it should
contains all the domains you wish to handle with this Postfix instance. In my
case I use the `$mydomain` option, and a subdomain:

~~~
virtual_mailbox_domains = $mydomain b.$mydomain
~~~

Next we setup the base folder of all virtual e-mails, this is defined using
`virtual_mailbox_base`[^postfix_virtual_mailbox_base], at the same time we
setup the limit size of the virtual mail using
`virtual_mailbox_limit`[^postfix_virtualmailbox_limit] (as later on, I
personally set it to no limit, but otherwise it is a number in bytes)

~~~
virtual_mailbox_base = /var/vmail
virtual_mailbox_limit = 0
~~~

Now we will setup the list of virtual mailbox and alias using

{::comment} Footnote {:/comment}

[^seriously]: Yes seriously, some website explain you that even for 10 e-mails
              addresses it is better to setup MySQL...

[^postfix_myhostname]: <http://www.postfix.org/postconf.5.html#myhostname>

[^postfix_mydomain]: <http://www.postfix.org/postconf.5.html#mydomain>

[^postfix_myorigin]: <http://www.postfix.org/postconf.5.html#myorigin>

[^postfix_mydestination]: <http://www.postfix.org/postconf.5.html#mydestination>

[^postfix_inet_interfaces]: <http://www.postfix.org/postconf.5.html#inet_interfaces>

[^postfix_mynetworks]: <http://www.postfix.org/postconf.5.html#mynetworks>

[^postfix_relayhost]: <http://www.postfix.org/postconf.5.html#relayhost>

[^postfix_mailbox_size_limit]: <http://www.postfix.org/postconf.5.html#mailbox_size_limit>

[^postfix_recipient_delimiter]: <http://www.postfix.org/postconf.5.html#recipient_delimiter>

[^postfix_virtual_mailboxdomains]: <http://www.postfix.org/postconf.5.html#virtual_mailboxdomains>

{::comment} Link {:/comment}

[open_relay]: http://en.wikipedia.org/wiki/Open_relay

{::comment} Abbrevation {:/comment}

*[MTA]: Mail Transfer Agent
*[SMTP]: Simple Mail Transfer Protocol
*[POP]: Post Office Protocol
*[IMAP]: Internet Message Access Protocol
