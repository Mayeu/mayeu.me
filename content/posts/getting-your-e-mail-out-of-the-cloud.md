---
kind: article
title: 'Getting your e-mails out of the cloud: Debian, OpenSMTPD, Dovecot'
created_at: 2013-05-26
tags: cloud, howto
---

I recently (ie.: 7 months ago) wanted to get out of Gmail and finally set up my
own e-mail server. After some day fighting my way through Postfix and Dovecot,
I finally got it up and running.

But after the announce of the production ready version of OpenSMTPD, I got rid
of Postfix, and switch to OpenSMTPD. So this article should have been about
Postfix, but it will be about OpenSMTPD instead.

## What will be set up
{:.no_toc}

First of all, my goal is not about serving e-mail to thousands of customers, or
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
* Anti-spam thingie (in a near futur, currently I still do not have any spam on my addresses).

## What will NOT be set up
{:.no_toc}

I do not plan to teach you GNU/Linux or to administrate Debian. You should have
some (small) knowledge of the \*nix you plan to use, and of the glorious
command line. I will not explain to you the whole client part to send and get
your mail on your desktop/smartphone/coffee brewer/toaster/...

And finally, this is not a short article with a copy-this-conf-and-voilà style.
First, because this generaly do not work, and second, because if something
break later on you will have no idea of what is the problem.

Now let's start :)

## TOC
{:.no_toc}
* toc
{:toc}

## Basic Introduction to e-mail

>Warning, the following text is really basic! You have been warned.

Basically, e-mail work around a peer-to-peer network of servers that relay
e-mail through the SMTP protocol. That is basically all.

To know where to send the e-mail, we use the MX fields of your DNS. You can
have multiple MX fields with different priorities, which allow you to setup
multiple server. When a high priority server is down, the e-mail will be send
to a lower priority server and again if it is down, until it reach a MX field
pointing to a up server.

After some time, your lower priority server will try to send back the mail to
a higher one to ensure proper delivery.

## Settings the MX fields

So, say you manage the domain `example.org`. You have to add something like
this in your DNS:

~~~
mx1           IN A     0.0.0.1
mx2           IN A     0.0.0.2
.example.org. IN MX 1  mx1.example.org.
.example.org. IN MX 10 mx2.example.org.
~~~

The number after the MX declaration are the priorities. The lowest priority
will be tested first.

Also, do not forget (like I did) to setup your `AAAA` fields if you have ipv6
addresses. It save you debug time later on.

## Installing OpenSMTPD on Debian

At the time I setup my server, there is no official package for Debian (it
seems that the main dev of OpenSMTPD have create a amd64 package for it's own
need, you can found it
[here](http://www.opensmtpd.org/archives/packages/debian/). Personally I needed
a armhf version (for my Raspberry Pi), so I compiled my version.)

First, you need to install all the tools to compile the code:

~~~
# apt-get install build-essential bison automake libtool libdb-dev libssl-dev libevent-dev
~~~

Next, download and untar the portable version here:
`http://www.opensmtpd.org/archives/opensmtpd-5.3.3p1.tar.gz`

You can then bootstrap, configure and compile everything. To make it more
Debian friendly, we add some prefix and sysconfdir option to configure. I sure
there is room for improvement in this option.

~~~
# ./bootstrap
# ./configure --prefix="/usr" --sysconfdir="/etc"
# make
# make install
~~~

OpenSMTPD use 3 different users enabling good privileges separation, and its
launched chrooted in `/var/empty` by default. The users names start with an
underscore, which is a standard in BSD but not in Linux, if its bother you can
change the `configure` file with username you wish.

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

Just before going head first in the OpenSMTPD configuration, this command may
help you during the configuration:

* Test the config file: `smtpd -n`
* Launch OpenSMTPD in foreground and with debug output: `smtpd -dv`
* Trace some worker: `smtpctl trace <name>`
* See the queue: `smtpctl show queue`
* See some message: `smtpctl show <msg_id>`
* Schedule things: `smtpctl schedule`

The `smtpctl` command can do a lot of usefull things, check it :)

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
(the OpenBSD firewall) and is really readable & understandable.

By default, all the e-mail are rejected, and the `accept` rule allow you to
select what e-mail will be accepted. `for local` filter the e-mail that are
destinated to the local account, and the `alias` check a table to check if the
account exist (en redirect to the good alias). And finally `deliver to mbox`
deliver the e-mail to mbox (thank Captain!). You can also deliver to maildir,
mta, and maybe other (read the fine manual ;))

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

### Checking for open relay

To check for an open relay I used those two website:
[mailradar](http://www.mailradar.com/openrelay/) and
[mtoolbox](http://mxtoolbox.com/). With the previous configuration, you should
not be an open relay :)

### Sending e-mail with SMTP submission

We are now able to receive e-mail, and send them from the local machine. But we
want to be able to submit e-mail from other computer. It is time to add SMTP
submission and auth.

First we have to create the user we will be using to access the SMTP. I have
created a /etc/smtpdauth file to contains all the smtpauth users:

~~~
#User smtpd auth
mayeu  mayeu:hashpassword
~~~

You can put your password in plain text, but it is better to hash them.  It use
the standard `crypt (3)` function of your system. Personally I used the Perl
crypt function to build a hash (see the `crypt (3)` manpage for more info and how
its work):

~~~
$ perl -e 'print crypt("mysupersecretpassword","\$6\$thesupersalt\$"), "\n"'
$6$thesupersalt$NTH5FbDaiFCq93bQbvuBnf8tP.tnUSj8djA8UVO2tYlXPf2/6bbDl8sUDs71Ndx8xmq2n6QcG4Gac50NvHPQM.
~~~

We declare a new table in our `/etc/smtpd.conf`:

~~~
# Declare the in_auth table
table in_auth file:/etc/smtpdauth
~~~

An we add the rule to listen for submission through SMTP:

~~~
# Listenning on internet interface for submission (port 587)
listen on eth0 port 587 tls-require certificate mail.example.org auth in_auth
~~~

So, we `listen on eth0 port 587` using `tls-require` with the `certificate
mail.example.org` (you can create and use an other certificate if you wish).
And we filter the connection using the `auth in_auth` table.

And that's all, since we have a `accept for any relay` the mail will be relayed
automatically. You can try to send an e-mail with a client now, and everything will
work :)

There is the current `/etc/smtpd.conf` file:

~~~
# Declare the alias table
table aliases file:/etc/aliases

# Declare the vuser
table vusers file:/etc/vusers

# Declare the in_auth table
table in_auth file:/etc/smtpdauth

# Listen on the local interface
listen on lo

# Listen on the internet interface
listen on eth0 tls certificate example.org

# Listenning on internet interface for submission (port 587)
listen on eth0 port 587 tls-require certificate shoggoth.tc2.fr auth <in_auth>

# Deliver example.org e-mail to maildir
accept from any for domain example.org virtual aliases userbase vusers deliver to maildir "~/"

# Deliver local accounts
accept for local virtual aliases deliver to mbox

# Relay every other mail
accept for any relay
~~~

## This is spam, I want ham

We are able to send e-mail, but currently  we are considered spam by 
most of the other computer. To prevent this, we have to:
* Correctly configure ou reverse DNS
* Add a SPF record in our DNS record
* Add a DKIM signature to the mail, and the key in our DNS record

### Reverse DNS

This will depend of your provider. There is no general rule, and you may not
even be able to set it to the value you wish. The idea is that the domain your
e-mail use should resolved to an IP that will be reversed to your domain (it is
a really basic spam countermeasure).

### SPF

SPF stand for Sender Policy Framework. It is a set of rules your setup in your
DNS record that will prevend e-mail spoofing by verifying the send IP address.
See [wikipedia](http://en.wikipedia.org/wiki/Sender_Policy_Framework) for all the
rules and possibility. Personaly my SPF rules is:

~~~
       3600 IN TXT    "v=spf1 a mx -all"
~~~

It will only accept IP that are a `A` or `MX` field in my DNS record.

### DKIM

DKIM is a asymetric signature system. The idea is that you provide a public key
in your DNS record, and your server sign every outgoing mail with the associated
private key. This will show that the mail originate only from your domain, since
you will be the only one that can sign the e-mails with this key.

#### DKIMProxy

To do this we will use a signing proxy named DKIMProxy:

~~~
# apt-get install dkimproxy
~~~

During the install dkimproxy will generate the needed key in
/var/lib/dkimproxy/*.key. But as with the ssl certificate, you
can generate your own key, or use an excisting key.

Open the file `/etc/dkimproxy/dkimproxy_out.conf` (the `dkimproxy_in.conf` is
for the verifying proxy to check incomming mail, I won't set it up personally,
at least until my e-mail received too much spam.)

Change the domain line:

~~~
# specify what domains DKIMproxy can sign for (comma-separated, no spaces)
domain    example.org
~~~

Update the keyfile path:

~~~
# specify location of the private key
keyfile  /var/lib/dkimproxy/private.key
~~~

Change the selector value to whatever you wish (in my case I put smtpd):

~~~
# specify the selector (i.e. the name of the key record put in DNS)
selector  smtpd
~~~

This value will be used in your DNS record. This allow you to have different
private key for different e-mail sending server in the same DNS record.

You can now restart dkimproxy.

#### DNS Record

Now we will add the field in the DNS record. Open your public key (default path
`/var/lib/dkimproxy/public.key`) and add the following to your DNS:

~~~
<selector_name>._domainkey   3600 IN TXT    "k=rsa; t=y; p=your_public_key"
~~~

In my case the value are:

~~~
smtpd._domainkey   3600 IN TXT    "k=rsa; t=y; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDaY7SvV9yhocQYoQbRcnXMazzyTJO7FGtj4s+BGuGT5OLhy3Fkhwwn1apYENuCBrRqMbWo6ENDO+e731u05Rakf43eSZUKfRAd09tNhlooeyVnO//6Lu+aeArrG+t9mC19xDeTjdTsYsLj3g+Pp9silfuJAs8g9SWfIv+vQ0//3wIDAQAB"
~~~

Also add the following :

~~~
_domainkey         3600 IN TXT    "o=-"
~~~

This rules specify that all the outgoing e-mails will be signed. It is the same
kind of rules than the SPF, you can search for the DKIM RFC if you wish to
check all the rules and value possible.

#### OpenSMTPD

Back to `/etc/smtpd.conf`, we will start to use tag to redirect the message
throught DKIMProxy.

Add `tag TO_DKIM` at the end of the rule listen on the submission port:

~~~
# Listenning on internet interface for submission (port 587)¬
listen on eth0 port 587 tls-require certificate mail.example.org auth in_auth tag TO_DKIM
~~~

Now we add a rule that match every e-mails `tagged` with `TO_DKIM`, and send it
to DKIMProxy:

~~~
# Send to dkim
accept tagged TO_DKIM for any relay via smtp://127.0.0.1:10028
~~~

Now we have to listen to the e-mail send back by the proxy:

~~~
# Listen from DKIMproxy
listen on lo port 10029
~~~

And that is all :) Your outgoing e-mail should be signed. In your `mail.log` you should
see these kind of log messages:

~~~
DKIM signing - signed; message-id=<20130526003359.412d0720@cthulhu>
~~~

And if you check the header of the sent mail, you should see the signature You
can "debug" any problem using the [port25
service](http://www.port25.com/support/authentication-center/email-verification/),
this will help you to easily check if your e-mail are ham or spam, if the SPF
allow the e-mail, and if it is correctly signed. Do not forget to wait the time
your DNS record propagate! Also, if your server support IPV4 and IPV6, ensure
that your DNS record also have the IPV4 and IPV6 address for all fields related
to e-mail.

## Dovecot

Now we will add support of IMAP using Dovecot. As previously stated, it is not
possible at this time to use only one vusers config for both OpenSMTPD and
Dovecot.

First install the needed package:

~~~
sudo apt-get install dovecot-core dovecot-imapd
~~~

Open `/etc/dovecot/conf.d/10-auth` and uncomment the following lines:

~~~
disable_plaintext_auth = yes
...
... # lots of lines
...
!include auth-passwdfile.conf.ext
~~~

The last uncomment will activate the possibility to log into Dovecot using a
passwd like file.

Create `/etc/dovecot/users` with the detail of your virtual users, using the
folowing syntax (you should note that this file is define in the
`/etc/dovecot/conf.d/auth-passwdfile.conf.ext` file):

~~~
username:password:GUID:UID::HOME::userdb_mail=maildir:~/
~~~

You should put the same `GUID`, `UID`, `HOME` and maildir folder than the ones
of your OpenSMTPD virtual users.

Personnaly it gives me:

~~~
m:password:5000:5000::/var/vmail::userdb_mail=maildir:~/
~~~

Now activate ssl in `/etc/dovecot/conf.d/10-ssl` by setting `ssl=required` (A
default certificate as been generated at the installation).

And that is all, just restart Dovecot and you should be able to reached IMAP on
the port 143 :)

## Secondary (tertiary,...) server:

To enable a server to be used as a secondary server, and to retains e-mail when
waiting for a the main server to be back up just add the following in your
configuration:

~~~
# Backup for example.com mail¬
accept from any for domain exemple.com relay backup mx2.example.com
~~~

As you see it is almost the same as relaying our other e-mail, but we add the
`backup` command with the domain name of one of the MX fields of your DNS
record (not the primary one!). When OpenSMTPD will receive an e-mail, for this
domain, it will check all the MX field, find the one you specify, and try to
relay the e-mail to the domain with greater priority than the one define.

## Conclusion

There is the final OpenSMTPD configuration:

~~~
# ###########
# Table setup
# ###########

# Declare the alias table
table aliases file:/etc/aliases

# Declare the vuser
table vusers file:/etc/vusers

# Declare the in_auth table
table in_auth file:/etc/smtpdauth

# #################
# Listen interfaces
# #################

# Listen on the local interface
listen on lo

# Listen on the internet interface
listen on eth0 tls certificate example.org

# Listenning on internet interface for submission (port 587)
listen on eth0 port 587 tls-require certificate shoggoth.tc2.fr auth in_auth tag TO_DKIM

# Listen from DKIMproxy
listen on lo port 10029

# ##############
# Matching rules
# ##############

# Backup for example.com mail¬
accept from any for domain exemple.com relay backup mx2.example.com

# Send to dkim
accept tagged TO_DKIM for any relay via smtp://127.0.0.1:10028

# Deliver example.org e-mail to maildir
accept from any for domain example.org virtual aliases userbase vusers deliver to maildir "~/"

# Deliver local accounts
accept for local virtual aliases deliver to mbox

# Relay every other mail
accept for any relay
~~~

I found this much more simpler and easier to read than postfix :) I did not
show you everything that is possible with OpenSMTPD, you can use SQL backend
for the table, BerkelyDB, and even LDAP (experimental for now).  The set of
rules is small, but when combined you can make powerful things :)

If you see errors, unclear, or dumb things in this article, do not hesitate to
drop me an e-mail, you can found my contact [here](/contact).

And before you go, OpenSMTPD had a quick evolution those last months, and a lot
of documentation out there is outdated. Beware! In doubt, refer to the manpage ;)

## Source

This is almost all the webpages I read to achieve this. This list may contains
things that are
[irrelephant](http://www.maniacworld.com/anything-unrelated-is-irrelephant.jpg):

* [OpenSMTPD website](http://www.opensmtpd.org/)
* [OpenSMTPD presentation](http://www.opensmtpd.org/presentations/asiabsdcon2013-smtpd/)
* [smptd.conf manpage](http://www.opensmtpd.org/smtpd.conf.5.html)
* [OpenSMTPD: fully virtual setups, updated DNS & MTA code, SQLite support](https://www.poolp.org/0x7316/OpenSMTPD:-fully-virtual-setups-updated-DNS--MTA-code-SQLite-support)
* [config pr0n](http://thread.gmane.org/gmane.mail.opensmtpd.general/501/focus=505)
* [Le mail sous OpenBSD](http://www.openbsd-edu.net/index.php/Le_mail_sous_OpenBSD#OpenSMTPd)
* [OpenSMTPD "how to"](https://calomel.org/opensmtpd.html)
* [My OpenSMTPD Config](http://www.room425.com/?p=60)
* [Installing OpenSMTPD on Debian Linux](http://bogoflop.com/debian_install_opensmtpd.html)
* [OpenSMTPD + Debian 6.0 Squeeze HowTo](http://maniatux.fr/index.php?article274/opensmtpd-debian-6-0-squeeze-howto)
* [OpenSMTPD sur OpenBSD 5.0 avec tls auth + relay](http://maniatux.fr/?article239/opensmtpd-sur-openbsd-5-0-avec-lts-auth-relay)
* [Aliases to external e-mail addresses](http://permalink.gmane.org/gmane.mail.opensmtpd.general/428)
* [OpenBSD SMTPd](http://wiki.defcon.no/guides/opensmtpd)
* [Sender Policy Framework](http://en.wikipedia.org/wiki/Sender_Policy_Framework)
* [DomainKeys_Identified_Mail](http://en.wikipedia.org/wiki/DomainKeys_Identified_Mail)
* [port25 e-mail verification](http://www.port25.com/support/authentication-center/email-verification/)
* [Installation de DKIMProxy sur Postfix](https://admin-serv.net/blog/165/installation-de-dkimproxy-sur-postfix/)
* [DomainKeys RFC](http://www.ietf.org/rfc/rfc4870.txt)
* [DKIMProxy usage](http://dkimproxy.sourceforge.net/usage.html)
* [DKIM/Domainkeys signing via DKIMproxy](http://www.thatsgeeky.com/2011/05/dkimdomainkeys-signing-via-dkimproxy/)
* [How to create an SHA-512 hashed password for shadow?](http://serverfault.com/questions/330069/how-to-create-an-sha-512-hashed-password-for-shadow)
* [Dovecot SSL certificate](http://wiki2.dovecot.org/SSL/CertificateCreation)
* [Dovecot Passwd file](http://wiki2.dovecot.org/AuthDatabase/PasswdFile)
