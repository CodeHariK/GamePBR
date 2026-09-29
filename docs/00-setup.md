# Step 00 — Project setup & toolchain

> Part of the **GamePBR** devlog. Language: Odin · Target: CPU renderer → WebGPU.

**Status:** scaffold ready — `make run` should open a window with a gradient.
**Goal:** Get an Odin project building, open a window, and get CPU pixels onto the screen — with the windowing library behind a seam so it can be swapped for WebGPU later without touching the renderer.

## What & why
Before any rasterizing or shading, I need one thing working end to end: a chunk of memory I write colors into (the framebuffer), and a way to see it on screen every frame. That's the whole harness the CPU phase runs on.

The one design decision worth making now is **isolation**. raylib is the right tool for the CPU phase (trivial to blit a pixel buffer), but at step 18 the display layer becomes GLFW + WebGPU. So the renderer never talks to raylib directly — it talks to a tiny `Display` interface (four procedures). Swapping backends later means replacing one file.

## Theory
**Odin's package model.** A package is a directory. Every `.odin` file in `src/` starts with `package main` and shares the same namespace, so `Framebuffer`, `Color`, and the display procs are all visible to each other with no imports between them. The package containing `main :: proc()` builds to an executable.

**Why a proc-field "vtable" for the seam.** Odin has no interfaces. The idiomatic way to make a swappable backend is a struct that holds function pointers (`present`, `poll_input`, …) plus an opaque `rawptr` for backend state. The renderer calls `display.present(&display, &fb)` and never knows or cares that raylib is on the other side. The indirection cost is one pointer call per frame — irrelevant.

**Color layout.** GPUs want `R8G8B8A8`. If our `Color` struct is exactly `{r, g, b, a: u8}` (4 bytes, no padding), a `[]Color` is already in the exact byte layout the texture upload expects — so `raw_data(fb.pixels)` goes straight to `UpdateTexture` with zero conversion.

## Implementation
Four small files, one responsibility each:

- **`src/framebuffer.odin`** — the `Color` and `Framebuffer` types, plus create/destroy/clear/set. Knows nothing about how it reaches the screen.
- **`src/display.odin`** — the seam: the `Display` struct (four proc fields + `user_data`) and the `Input` struct.
- **`src/display_raylib.odin`** — the *only* file that imports raylib. Creates a window, keeps one GPU texture, and each frame uploads the framebuffer and blits it.
- **`src/main.odin`** — wires it together and runs the loop; for now it draws a gradient as proof-of-life.

The core loop:

```odin
for !display.should_close(&display) {
	input := display.poll_input(&display)
	if input.quit do break

	draw_test_gradient(&fb)      // steps 03+ replace this with the rasterizer

	display.present(&display, &fb)
}
```

And the raylib present, the heart of the CPU→screen path:

```odin
rl.UpdateTexture(backend.texture, raw_data(fb.pixels)) // CPU pixels -> GPU
rl.BeginDrawing()
rl.DrawTexture(backend.texture, 0, 0, rl.WHITE)         // blit 1:1
rl.EndDrawing()
```

**Build:** `make run` (debug) or `make release` (optimized). Under the hood: `odin run src -out:gamepbr -debug`.

## Results
A 800×600 window titled "GamePBR" showing a red-across / green-down gradient with an FPS counter. If you see it, the toolchain, the framebuffer, and the display seam all work.

![result](img/00-setup.png)

## Gotchas
- **raylib comes with Odin.** No separate install — it's `import rl "vendor:raylib"` and Odin ships prebuilt libs for macOS, so linking is automatic. Just have the `odin` compiler on your PATH.
- **Color format must match.** If the texture isn't `R8G8B8A8`, the upload will show garbled/swapped channels. `GenImageColor` defaults to that format, which is why it's used to seed the texture.
- **`UpdateTexture` re-uploads the whole buffer every frame.** Fine now; it's a real cost later at high res. Noted for the performance pass (step 17), not worth optimizing yet.
- **ESC.** raylib closes the window on ESC by default via `WindowShouldClose()`; `poll_input` also reports it as `quit` so the app has one explicit exit path.
- **One package, for now.** Everything is `package main`. When files multiply (post step ~06), split into sub-packages (`math`, `render`) — each becomes its own directory.

## References
- Odin docs — overview & `vendor:raylib`: https://odin-lang.org/docs/
- raylib cheatsheet: https://www.raylib.com/cheatsheet/cheatsheet.html

## Next
→ **Step 01 — Math foundations**
