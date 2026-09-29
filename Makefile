ODIN ?= odin
SRC  := src
OUT  := gamepbr

# debug build + run
run:
	$(ODIN) run $(SRC) -out:$(OUT) -debug

# optimized build
release:
	$(ODIN) build $(SRC) -out:$(OUT) -o:speed

# unit tests
test:
	$(ODIN) test src/math
	$(ODIN) test src/render

.PHONY: run release test
