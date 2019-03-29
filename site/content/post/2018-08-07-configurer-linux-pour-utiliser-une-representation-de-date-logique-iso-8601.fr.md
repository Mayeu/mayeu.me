---
layout: post
title: "Configurer Linux pour utiliser une représentation de date logique (ISO 8601)"
category: blog
translationKey: configure-linux-iso-8601
lang: fr
date: 2018-08-07
---

Durant l'une de mes nombreuses reconfigurations de Linux, je me suis demandé
s'il était possible d'utiliser le standard [ISO 8601][iso] pour l'affichage des
dates. Il s'agit du standard définissant le format `2018-08-07` (et plein
d'autres choses, comme l'heure en format 24 heures).

Pour configurer ce genre de choses sur Linux, on utilise le système de
[paramètres régionaux][locale] (« locale » en anglais). La plupart du temps, on
s'arrête à configurer la variable `LANG` pour utiliser notre propre langage
(`LANG=fr_FR.UTF-8`) et basta. Mais il y a bien d'autres variables (comme
`LC_NUMERIC`, `LC_MONETARY`, `LC_PAPER`), et pour notre cas de figure on
utilisera `LC_TIME`.

Il s'avère qu'il existe un paramètre régional `en_DK` (qui est vraiment un
hack, puisque l'anglais n'est pas vraiment officiel au Danemark) qui utilise le
standard ISO 8601 !

Avec ça on peut donc configurer son système avec `LC_TIME=en_DK.UTF-8` et
atteindre le nirvana des dates 🙏

*Nota bene : comme son nom l'indique, le paramètre `en_DK` passe les dates en
anglais. Utilisant mon système dans cette langue ça ne me pose pas de problème,
malheureusement à ma connaissance il n'y a pas d'équivalent français pour ces
paramètres :(*

[iso]: https://fr.wikipedia.org/wiki/ISO_8601
[locale]: https://fr.wikipedia.org/wiki/Param%C3%A8tres_r%C3%A9gionaux
