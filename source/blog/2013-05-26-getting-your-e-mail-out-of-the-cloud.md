---
title: 'Getting your e-mails out of the cloud: Debian, OpenSMTPD, Dovecot'
date: 2013-05-26
published: false
tags: cloud, howto
---

I recently wanted to get out of Gmail and finally set up my e-mail server.
After some day fighting my way through Postfix, Dovecot, I finally got it up
and running.

But after the announce of the production ready version of OpenSMTPD, I got rid
of Postfix, and switch to OpenSMTPD. So this article should have been about
Postfix, but it will finally be about OpenSMTPD.

Since I had to get all the info from multiple sources and documentation, I
decided to write about my configuration in one place.

## What will be set up
{:.no_toc}

First of all, my goal is not about serving e-mail to thousand of customers, or
providing an e-mail service to other peoples than me. So I wanted to keep it
simple, no DBMS, everything in flat file, the minimum of configuration, the
minimum of softwares, no webmail (for now at least).

My server run Debian 7, so this little guide is made with Debian in mind, but I
am sure it can be pretty easily ported to any other GNU/Linux (I also made a
working config on Archlinux), or even \*nix.

There is what I choose to setup and play with:

* OpenSMTPD: to handle SMTP, relaying, and receiving e-mails.
* Dovecot: to handle IMAP. This protocol may not be a good choice if your e-mails are sensible.
* Virtual e-mail account: e-mail account are not linked to actual GNU/Linux account.
* Maildir format.
* Flat file for frak sake.
* A secondary server in case your main is down.
* Anti-spam thingie (in a near futur, currently still not have any spam on my addresses).

## What will NOT be set up
{:.no_toc}

I do not plan to teach you GNU/Linux or to administrate Debian. You should have
some (small) knowledge of the \*nix you plan to use, and of the glorious
command line. I will not explain to you the whole client part to send and get
your mail on your desktop/smartphone/coffee brewer/toaster/...

And finally, this is not a short article with a copy-this-conf-and-voilà style.
First, because this generaly do not work, and second, because if something
break later on you will have no idea of what is the problem.

Let's start :)

* toc
{:toc}

## Basic Introduction to e-mail

Warning, the following text is really basic. You have been warned.

Basically, e-mail work around a peer-to-peer network of servers, that relay
e-mail through the SMTP protocol. That is basically all. To know where to send
the e-mail, we use the MX fields of the DNS. You can have multiple MX fields
with different priority, which allow you to setup multiple server, so when a
high priority server is down, the e-mail will be send to a lower priority
server and again if it is down, until it reach a MX field pointing to a up
server.

## Settings the MX fields

So, say you manage the domain `example.org`. You have to add something like
this in your DNS:

~~~
mx1           IN A     0.0.0.1
mx2           IN A     0.0.0.2
.example.org. IN MX 1  mx1.example.org.
.example.org. IN MX 10 mx2.example.org.
~~~

## Installing OpenSMTPD on Debian

At the time I setup my server, there is no official package for Debian (it
seems that one of the main dev of OpenSMTPD have create a amd64 package for
it's own need, you can found it
[here](http://www.opensmtpd.org/archives/packages/debian/). Personally I needed
a armhf version (for my Raspberry Pi), so I compiled my version.)

First, you need all the needed tools to compile the code:

~~~
# apt-get install build-essential bison automake libtool libdb-dev libssl-dev libevent-dev
~~~

Next, download and untar the portable version here:
`http://www.opensmtpd.org/archives/opensmtpd-5.3.2p1.tar.gz`

You can then bootstrap, configure and compile everything. To make it more
Debian friendly, we add some prefix and sysconfdir option to configure.

~~~
# ./bootstrap
# ./configure --prefix="/usr" --sysconfdir="/etc"
# make
# make install
~~~

OpenSMTPD use 3 different user to have a good privilege separation, and its launched
chrooted in `/var/empty` by default. The users names start with an underscore, which is
a standard in BSD but not in Linux, if its bother you can change the configure file with
username you wish.

Create the users and the home folder:

~~~
# useradd -c "SMTP Daemon" -d /var/empty -s /sbin/nologin _smtpd
# useradd -c "SMTP Queue" -s /sbin/nologin _smtpq
# useradd -c "SMTP Filter" -s /sbin/nologin _smtpf
# mkdir /var/empty
~~~

If you had an other MTA before the installation of OpenSMTPD, deactivate it.
In Debian the default is generally Exim4:

~~~
# service exim4 stop
# update-rc.d exim4 disable
~~~

## Setting up OpenSMTPD

### Local email reception

First basic settings, we setup the local e-mail reception to our personnal
account. The standard file used in debian for creating aliases is
`/etc/aliases`. So, I redirect everything to `root`, and `root` to `pi` (which
is my local user):

~~~
# Aliases
mailer-daemon:   postmaster
postmaster:      root
nobody:          root
hostmaster:      root
usenet:          root
news:            root
webmaster:       www
www:             root
ftp:             root
abuse:           root
noc:             root
security:        root
root:            pi
~~~

Now we create the basic opensmtpd config in `/etc/smtpd.conf` and we declare our
alias table:

~~~
# Declare the local alias table
table aliases file:/etc/aliases
~~~

The `table` command allow you to declare a table with the following syntax:
`table table_name [type:]path_to_file`. In our case, the type is a simple file,
check the manpage for all the supported type.

Now we have to listen on the local network interface:

~~~
# Listenning on local interface
listen on lo
~~~

And we deliver the mail:

~~~
# Deliver local account
accept for local alias <aliases> deliver to mbox
~~~

As you see, the configuration look like [pf](http://www.openbsd.org/faq/pf/)
(the OpenBSD firewall) and its really readable.

By default, all the e-mail are rejected, and the `accept` rule allow you to
select what e-mail will be accepted. `for local` filter the e-mail that are
destinated to the local account, and the `alias` check a table to modify the
recipient of the message.  And finally `deliver to mbox` deliver the e-mail to
mbox (thank Captain!). You can also deliver to maildir, mta, and maybe other
(read the fine manual ;))

You can check your configuration with:

~~~
# smtpd -n
configuration OK
~~~

Ok, but I personally prefere to receive all this local e-mail to an other
e-mail address (later on we will add the virtual account support). So I changed
my `/etc/aliasses` like this:

~~~
# Aliases
mailer-daemon:   postmaster
postmaster:      m+postmaster@example.org
nobody:          root
hostmaster:      root
usenet:          root
news:            root
webmaster:       www
www:             m+www@example.org
ftp:             root
abuse:           m+abuse@example.org
noc:             root
security:        m+security@example.org
root:            m+root@example.org
pi:              m+pi@example.org
~~~

To enable that you just have to change the last line of your config from
`accept for local alias` to `accept for local virtual` and to add a rule to
relay external e-mails (with the `relay` command):

~~~
# Deliver local account
accept for local virtual <aliases> deliver to mbox

# Relay every other mail
accept for any relay
~~~

Now all alias pointing to an e-mail will be relayed to the good SMTP server,
and all the local aliases will be delivered to the users mailbox. You should
know that even if you do not have aliases pointing to a local or virtual inbox,
you need the `deliver to` command.

### Receiving e-mail

Now it is time to receive some e-mails.

#### TLS

Before receiving e-mail, we will generate a certificate for our server to
listen and connect with TLS. This is not an obligation, but you really should
encrypt the maximum of things you use. (Remember kids, you should encrypt all
the things)

Create the certs folder in `/etc/certs/` (I did not find yet a way to configure
the folder in an other place), and we generate the certificate :

~~~
# openssl genrsa -out /etc/certs/mail.example.com.key 4096
# openssl req -new -x509 -key /etc/certs/mail.example.com.key \
     -out /etc/certs/mail.example.com.crt -days 365
# chmod 600 /etc/certs/mail.example.com.*
~~~

Now we can listen on eth0 with tls support, and pointing to our certificate using
the `tls certificate` command:

~~~
# Listenning on the eth0 interface
listen on eth0 tls certificate mail.example.com
~~~

#### Creating the virtual user

As I stated before, I use only virtual users, to achieve this I setup a `vmail`
account that will contains all my virtual user in `/var/vmail/virtualuser`.

Currently you can not use a passwd type file, so we will have to have a file
with our virtual username and password (but only for the SMTP
authentification), and an other file with the virtual user description (uid,
guid, home). This will also prevent us to have one common file for the virtual
users of OpenSMTPD and Dovecot. In a futur version OpenSMTPD may support passwd
type file.

So, I add my vmail user in my `/etc/passwd` :

~~~
vmail:x:5000:5000::/var/vmail:/usr/sbin/nologin
~~~

and the associated group in `/etc/group`:

~~~
vmail:x:5000:
~~~

Do not forget the home folder:

~~~
# mkdir /var/vmail
# chown vmail:vmail /var/vmail
~~~

I want to create a virtual user named `m` who will receive e-mail from
`m@example.org` and `mayeu@example.org`. I begin by activating the virtual
domain and adding the virtual aliases in my `/etc/aliases`:

~~~
# My virtual addresses
example.org:        true
m@example.org       m
mayeu@example.org   m
~~~

The syntax is slighty different than the local aliases. First you have to
activate the virtual domain (may not be needed if it is the name of your
server), and after you just put the addresses followed by the account name
without the colon.

Now we create the virtual users file, I personally put them in `/etc/vusers`,
but I am sure you can put them somewhere else, and even maybe in your
`/etc/aliases`:

~~~
# The virtual user
m     5000:5000:/var/vmail/m
~~~

The syntax is simple, the virtual account name in first, followed by the real
UID:GUID:folder where the mail will be delivered (so those values should be the
one you choose precedently)

#### Delivering the e-mails to the virtual users

In `/etc/smtpd.conf` we add the following to declare our virtual users:

~~~
# Declare the virtual users
table vusers file:/etc/vusers
~~~

And we deliver:

~~~
# Deliver example.org mail to maildir
accept from any for domain example.org virtual aliases userbase vusers deliver to maildir "~/"
~~~

We `accept` e-mail `from any` sources, sent to the `domain example.org` using
the `virtual aliases` table and the `userbase vusers` and we `deliver` them to
the `maildir "~/"` (which will be expanded to `/var/vmail/m/`). Easy right ?

And voilà, you can receive e-mail for your domain :)

### Current state of the configuration

`/etc/aliases`:

~~~
# Aliases
mailer-daemon:   postmaster
postmaster:      m+postmaster@example.org
nobody:          root
hostmaster:      root
usenet:          root
news:            root
webmaster:       www
www:             m+www@example.org
ftp:             root
abuse:           m+abuse@example.org
noc:             root
security:        m+security@example.org
root:            m+root@example.org
pi:              m+pi@example.org

# My virtual addresses
example.org:        true
m@example.org       m
mayeu@example.org   m
~~~

`/etc/vusers`:

~~~
# The virtual user
m     5000:5000:/var/vmail/m
~~~

`/etc/smtpd.conf`:

~~~
# Declare the alias table
table aliases file:/etc/aliases

# Declare the vuser
table vusers file:/etc/vusers

# Listen on the local interface
listen on lo

# Listen on the internet interface
listen on eth0 tls certificate example.org

# Deliver example.org e-mail to maildir
accept from any for domain example.org virtual aliases userbase vusers deliver to maildir "~/"

# Deliver local accounts
accept for local virtual aliases deliver to mbox

# Relay every other mail
accept for any relay
~~~

## Checking for open relay

To check for an open relay I used those two website:
[mailradar](http://www.mailradar.com/openrelay/) and
[mtoolbox](http://mxtoolbox.com/). With the previous configuratio, you should
not be an open relay :)

## Sending e-mail with SMTP submission

Now you can receive e-mail, it's time to send from client
- connect with tls required
- password required (you can setup ssl auth if you want also)
- using submission port

First the user will use to connect to smtpd.
I create a /etc/smtpdauth file to contains the smtpauth user:
~~~
#User smtpd auth
mayeu => mayeu:hashpassword}
~~~

You can put plain text password, or hash them. You should hash them.
It is the standard linux password hash, you can use perl to generate some:

`perl -e 'print crypt("mysupersecretpassword","\$6\$thesupersalt\$"), "\n"'`

It should return the following : `$6$thesupersalt$NTH5FbDaiFCq93bQbvuBnf8tP.tnUSj8djA8UVO2tYlXPf2/6bbDl8sUDs71Ndx8xmq2n6QcG4Gac50NvHPQM.`

(man 3 crypt for more detail)

don't forget to makemap

We declare the in_auth table:

~~~
# Setup in_auth table
table in_auth db:/etc/smtpdauth.db
~~~

Add the rule to listen fo submission:

~~~
# Listenning on internet interface for submission (port 587)
listen on eth0 port 587 tls-require certificate shoggoth.tc2.fr auth <in_auth>
~~~

port 587, listen on submission port
tls-require, we want tls
certificate mail.example.org, point to the certificate (same as the previous one, but you can create a new certificate for this if you wish)

And that's all, since we have a `accept for any relay` the mail will be relayed automatically. You can try to send an e-mail with a client.

To recap the config :

/etc/aliases:

~~~
# Classic alias
mailer-daemon:   postmaster
postmaster:      m+pipostmaster@6x9.fr
nobody:          root
hostmaster:      root
usenet:          root
news:            root
webmaster:       www
www:             m+piwww@6x9.fr
ftp:             root
abuse:           m+piabuse@6x9.fr
noc:             root
security:        m+pisecurity@6x9.fr
root:            m+piroot@6x9.fr
pi:              m+pi@6x9.fr

# My virtual addresses
tc2.fr:         true
m@tc2.fr        m
mayeu@tc2.fr    m
~~~

/etc/vusers:

~~~
# The virtual user
m               5000:5000:/var/vmail/m
~~~

/etc/smtpdauth:

~~~
# User smtpd auth
mayeu       mayeu:$6$thesupersalt$NTH5FbDaiFCq93bQbvuBnf8tP.tnUSj8djA8UVO2tYlXPf2/    6bbDl8sUDs71Ndx8xmq2n6QcG4Gac50NvHPQM.
~~~

/etc/smtpd.conf:

~~~
# Setup the alias table
table aliases db:/etc/aliases.db

# Setup the vuser
table vusers db:/etc/vusers.db

# Setup in_auth table
table in_auth db:/etc/smtpdauth.db

# Listenning on local interface
listen on lo
# Listenning on internet interface for relay (port 25)
listen on eth0 tls certificate shoggoth.tc2.fr
# Listenning on internet interface for submission (port 587)
listen on eth0 port 587 tls-require certificate shoggoth.tc2.fr auth <in_auth>

# Deliver tc2.fr mail to maildir
accept from any for domain tc2.fr virtual <aliases> userbase <vusers> deliver to maildir "~/"

# Deliver local account
accept for local virtual <aliases> deliver to mbox

# Relay every other mail
accept for any relay
~~~

## This is spam, I want ham

So, your smtp server is now up and running, but when you send e-mail to Gmail/Hotmail/whatever, it end up in the spam folder of your contact. This is not good.
- First things to set, set your reverse dns correctly to match your domain.
- Second thitgs to set, is the SPF in your DNS
- Third one, the dkim signature

For dkim we will install dkimproxy
`apt-get install dkimproxy`

During the install dkimproxy will generate the needed key in /var/lib/dkimproxy/*.key

Open the file /etc/dkimproxy/dkimproxy_out.conf (not dkimproxy_in is for checking incomming mail, I won't set it up personally)

Change the domain line, update the keyfile

Change selector to whatever you wish (in my case I put smtpd)
Remove "signature domainkeys" old

 Setup des valeurs dns, redémarrer dkimproxy

Dans opensmtpd on vas utiliser les tags pour envoyer les messages.
les messages entrant sont envoyé au proxy dkim, qui renvoie les messages à opensmtpd

On ajoute le tag TO_DKIM à l'écoute du port de submission.
on envoie les mail taggé à dkim avec :
~~~
# Send to dkim
accept tagged TO_DKIM for any relay via smtp://127.0.0.1:10027
~~~

Now we listen to the out address:porot of dkim with:
# Listen from DKIMproxy
listen on lo port 10029 tag FROM_DKIM

When you send an e-mail you should have the folowing : DKIM signing - signed; message-id=<20130526003359.412d0720@cthulhu> in your mail log

If you check the header of the sent mail, you should see the signature

# Dovecot

I did not succeed in my goal of one vusers config for opensmtpd and dovecot

`sudo apt-get install dovecot-core dovecot-imapd`

Open /etc/dovecot/conf.d/10-auth
Uncomment disable_plaintext_auth = yes (at the beginning)
Uncomment !include auth-passwdfile.conf.ext (at the end)

Create `/etc/dovecot/users` with the detail of your user, syntax:
username:password:guid:uid::home::userdb_mail=maildir:~/

I personnaly put the exact same things as opensmptd

ssl: open /etc/dovecot/conf.d/10-ssl set ssl=required

#  Backup server:

juste add :

~~~
# Backup for example.org mail¬
accept from any for domain exemple.org relay backup mx2.example.org
~~~

# Source
local to mail : http://permalink.gmane.org/gmane.mail.opensmtpd.general/428
vmail : http://www.opensmtpd.org/presentations/asiabsdcon2013-smtpd/#slide-18


