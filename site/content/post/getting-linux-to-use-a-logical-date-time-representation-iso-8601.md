---
layout: post
title: "Getting your Linux system to use a logical date & time representation (ISO 8601)"
category: blog
translationKey: configure-linux-iso-8601
lang: en
date: 2018-08-07
---

During one of my many Linux reconfiguration, I wondered if there was a way for
me to make it show the date and time by following the [ISO 8601][iso] standard.
If you don't know, that is the standard defining the date format as
`2018-08-07` (and other things, like 24-hour format, etc.).

The way you configure these kinds of things in Linux is via the
[locale][locale] system. Most of the time, we just configure the `LANG`
variable to match our own language (like `LANG=en_US.UTF-8`) and stop the
configuration there. But there are more variable than that (like `LC_NUMERIC`,
`LC_MONETARY`, `LC_PAPER` to name a few), and the one that interests us today
is `LC_TIME`.

It turns out that there is an `en_DK` locale (which is really a haked locale,
since English is not a language of Denmark), that follow the ISO 8601 standard!

So you can set up your time locale using  `LC_TIME=en_DK.UTF-8` and reach
datetime nirvana 🙏

[iso]: https://en.wikipedia.org/wiki/ISO_8601
[locale]: https://en.wikipedia.org/wiki/Locale_(computer_software)
