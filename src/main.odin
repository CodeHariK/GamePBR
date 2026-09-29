package main

import "core:fmt"
import "fb"
import "render"
import "utils"

WIDTH  :: 800
HEIGHT :: 600

main :: proc() {
	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	draw_scene(&f)

	if utils.write_ppm(&f, "depth.ppm") {
		fmt.println("wrote depth.ppm")
	}
	if utils.write_png(&f, "depth.png") {
		fmt.println("wrote depth.png")
	}

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}
		display.present(&display, &f)
	}
}

// Step 04: two triangles tilted in depth so they interpenetrate. Each is drawn
// as a flat color; the crossing seam where they swap in front is something only
// a depth buffer can produce (painter's-order drawing cannot).
draw_scene :: proc(f: ^fb.Framebuffer) {
	fb.clear(f, fb.Color{20, 20, 28, 255})
	fb.clear_depth(f, 1.0)

	// red: near on its left edge (z=0.2), receding to its right apex (z=0.8)
	render.triangle(f,
		render.Vertex{pos = {200, 150, 0.2}, color = {0.90, 0.25, 0.25}},
		render.Vertex{pos = {200, 450, 0.2}, color = {0.90, 0.25, 0.25}},
		render.Vertex{pos = {600, 300, 0.8}, color = {0.90, 0.25, 0.25}},
	)
	// blue: near on its right edge (z=0.2), receding to its left apex (z=0.8)
	render.triangle(f,
		render.Vertex{pos = {600, 150, 0.2}, color = {0.25, 0.45, 0.95}},
		render.Vertex{pos = {600, 450, 0.2}, color = {0.25, 0.45, 0.95}},
		render.Vertex{pos = {200, 300, 0.8}, color = {0.25, 0.45, 0.95}},
	)
}
