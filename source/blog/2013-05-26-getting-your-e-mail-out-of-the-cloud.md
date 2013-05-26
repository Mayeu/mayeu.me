---
title: 'Getting your e-mail out of the cloud with openSMTPD'
date: 2013-05-24
published: false
tags: cloud, howto
---

## Settings the MX

## Compiling openSMTPD on Debian

* Installing the needed package :
apt-get install build-essential bison automake libtool libdb-dev libssl-dev libevent-dev

* Download openSMTPD portable version
http://www.opensmtpd.org/archives/opensmtpd-5.3.2p1.tar.gz

* compiling
# ./bootstrap
# ./configure --prefix="/usr" --sysconfdir="/etc"
# make
# make install
# useradd -c "SMTP Daemon" -d /var/empty -s /sbin/nologin _smtpd
# mkdir /var/empty

* disable exim if present
# service exim4 stop
# update-rc.d exim4 disable

## Settings the mail reception for local

We set the local e-mail to redirect to your personnal addresses.

First, set up the aliases in the standard /etc/aliases (may not exist on your system):
   # Aliases¬
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

Make the db : `sudo makemap /etc/aliases`

Now create the basic opensmtpd config:

`touch /etc/smtpd.conf`

And add the following in /etc/smtpd.conf :

~~~
# Setup the alias table
table aliases db:/etc/aliases.db

# Listenning on local interface
listen on lo

# Deliver local account
accept for local alias <aliases> deliver to mbox
~~~

The `table` command allow you to point to key/values store (in BerkleyDB format in this case - see the `db:` -, but you can also have flat file)

Listen on lo allow you to listen to the internal interface

accept for local will accept local e-mail, alias check the aliases table, deliver to mbox will deliver it to the user inbox

Check your configuration : `smtpd -n`, should result in `configuration OK`

send a test mail `echo "test mail" | mailx root`

 You should receive it

That's great, but I personally prefere to receive all this local e-mail to a specific e-mail adresses.
Time to go on virtual users

I change my /etc/aliasses as:
   # Aliases
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

Just change the last line of your config from `accept for local alias` to `accept for local virtual` and we had a rule to relay all mail

~~~
# Setup the alias table
table aliases db:/etc/aliases.db

# Listenning on local interface
listen on lo

# Deliver local account
accept for local virtual <aliases> deliver to mbox

# Relay every other mail
accept for any relay
~~~

Now all alias pointing to an e-mail will be relayed to the good smtp, and all the classic
alias will be delivered to the users mailbox.

## Receiving e-mail

Before receiving e-mail, we need to generate a certificate for our server. This will allow use to receive e-mail using tls, which is better for your privacy. (remember kids, you should encrypt all the things)
Create the certs folder `mkdir /etc/certs/`, generate the certs :
# openssl genrsa -out /etc/certs/mail.example.com.key 4096
# openssl req -new -x509 -key /etc/mail/certs/mail.example.com.key \
     -out /etc/mail/certs/mail.example.com.crt -days 365
# chmod 600 /etc/certs/mail.example.com.*

Now we can listen to eth0 with tls support :

~~~
# Listenning on internet interface
listen on eth0 tls certificate mail.example.com
~~~

### Creating the virtual user

Personnaly I put all my virtual user's e-mails in `/var/vmail` owned by the vmail user defined as follow :
`vmail:x:5000:5000::/var/vmail:/usr/sbin/nologin` and the group vmail:
`vmail:x:5000:`

Now create the folder
`mkdir /var/vmail`
`chown vmail:vmail /var/vmail`

I want to create a virtual user name "m" who will receive e-mail from `m@example.org` and 
`mayeu@example.org`

So add the following in /etc/aliases

~~~
# My virtual addresses
example.org:        true
m@example.org       m
mayeu@example.org   m
~~~

The first line activate the virtual domain.
After there is the email adresses and the account that will received them

Now we create the users db, I put them in /etc/vusers, but I am sure you can put them somewhere else, and even maybe in /etc/aliases :

~~~
# The virtual user
m               5000:5000:/var/vmail/m
~~~

The syntax is simple, the virtual account name in first (m here), followed by the real UID:GUID:folder where the mail will be delivered

And now, we add the rule in /etc/smtpd.conf :

~~~
# Deliver example.org mail to maildir
accept from any for domain example.org virtual <aliases> userbase <vusers> deliver to maildir "~/"
~~~

accept from any, because we accept any source that send us an e-mail
for domain example.org, because we receive the mail for example.org
virtual <aliasses>, because we use the aliases
userbase <vusers>, because we do not want to use the system users
deliver to maildir "~/", because we want to deliver to the virtual home of the user, and directly in the home (/var/vmail/m in my case). If you do not put "~/" smtpd will create a ~/Maildir folder
And voilà, you can receive e-mail for your domain :)

Recap of all the file

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

/etc/smtpd.conf:

~~~
# Setup the alias table
table aliases db:/etc/aliases.db

# Setup the vuser
table vusers db:/etc/vusers.db

# Listenning on local interface
listen on lo
# Listenning on internet interface
listen on eth0 tls certificate shoggoth.tc2.fr

# Deliver tc2.fr mail to maildir
accept from any for domain tc2.fr virtual <aliases> userbase <vusers> deliver to maildir "~/"

# Deliver local account
accept for local virtual <aliases> deliver to mbox

# Relay every other mail
accept for any relay
~~~

## Checking for open relay

To check for an open relay I used http://www.mailradar.com/openrelay/ and http://mxtoolbox.com/SuperTool.aspx?action=smtp%3exemple.org&run=toolpage# and no open relay, that's cool :)

## Sending e-mail

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
username:password:guid:uid::home::usrdb_mail=maildir:~/

I personnaly put the exact same things as opensmptd

ssl: open /etc/dovecot/conf.d/10-ssl set ssl=required

# Source
local to mail : http://permalink.gmane.org/gmane.mail.opensmtpd.general/428
vmail : http://www.opensmtpd.org/presentations/asiabsdcon2013-smtpd/#slide-18


