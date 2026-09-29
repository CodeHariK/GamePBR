package main

import "fb"

// The display seam: everything the renderer needs from "the outside world"
// lives behind these four procedures. The raylib backend fills them in today;
// the WebGPU/GLFW backend replaces just display_raylib.odin at step 18.

Input :: struct {
	quit: bool,
	// grows in step 05: movement keys, mouse delta, etc.
}

Display :: struct {
	user_data:    rawptr, // backend-owned state, opaque to the renderer

	present:      proc(d: ^Display, f: ^fb.Framebuffer),
	poll_input:   proc(d: ^Display) -> Input,
	should_close: proc(d: ^Display) -> bool,
	destroy:      proc(d: ^Display),
}
