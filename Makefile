ODIN ?= odin
SRC  := src
OUT  := gamepbr

# debug build + run
run:
	$(ODIN) run $(SRC) -out:$(OUT) -debug

# optimized build
release:
	$(ODIN) build $(SRC) -out:$(OUT) -o:speed

.PHONY: run release
