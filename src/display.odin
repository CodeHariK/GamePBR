package main

// The seam. Everything the renderer needs from "the outside world" lives
// behind these four procedures. The raylib backend (display_raylib.odin)
// fills them in today; the WebGPU/GLFW backend replaces exactly this one
// file at step 18 and nothing in the renderer changes.

Input :: struct {
	quit: bool,
	// grows in step 05: movement keys, mouse delta, etc.
}

Display :: struct {
	user_data:    rawptr, // backend-owned state, opaque to the renderer

	present:      proc(d: ^Display, fb: ^Framebuffer),
	poll_input:   proc(d: ^Display) -> Input,
	should_close: proc(d: ^Display) -> bool,
	destroy:      proc(d: ^Display),
}
