package main

import "fb"

// The display seam: everything the renderer needs from "the outside world"
// lives behind these four procedures.

Input :: struct {
	quit:        bool,
	toggle_wire: bool, // 'W' pressed this frame
}

Display :: struct {
	user_data:    rawptr,

	present:      proc(d: ^Display, f: ^fb.Framebuffer),
	poll_input:   proc(d: ^Display) -> Input,
	should_close: proc(d: ^Display) -> bool,
	destroy:      proc(d: ^Display),
}
