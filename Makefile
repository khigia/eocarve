.PHONY: build
build:
	ocamlbuild \
    	-classic-display \
    	-cflags -I,+camlimages -lflags -I,+camlimages \
    	-libs graphics,ci_core,ci_jpeg,ci_png,ocamerl \
    	carve.native

.PHONY: clean
clean:
	ocamlbuild -clean
