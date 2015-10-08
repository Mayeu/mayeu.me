.PHONY: clean

all: build site

site: site.hs
	ghc --make -threaded $<

build: site css/* templates/* images/* posts/* *.html *.rst *.md
	./site build

watch: build
	./site watch -h 0.0.0.0

clean:
	./site clean
	rm -rf site *.hi *.o _site _cache
