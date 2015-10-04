.PHONY: clean

all: build site

site: site.hs
	ghc --make -threaded $<

build: site css/* templates/* images/* posts/* *.html *.rst *.markdown *.md
	./site build

watch: build
	./site watch

clean:
	./site clean
	rm -rf site *.hi *.o
