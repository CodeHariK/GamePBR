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

	if utils.write_ppm(&f, "triangle.ppm") {
		fmt.println("wrote triangle.ppm")
	}
	if utils.write_png(&f, "triangle.png") {
		fmt.println("wrote triangle.png")
	}

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	// The scene is static, so draw once and just present each frame.
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}
		display.present(&display, &f)
	}
}

// Step 03: one color-interpolated triangle on a dark background.
draw_scene :: proc(f: ^fb.Framebuffer) {
	fb.clear(f, fb.Color{20, 20, 28, 255})
	render.triangle(f,
		render.Vertex{pos = {400, 120}, color = {1, 0, 0}},
		render.Vertex{pos = {140, 500}, color = {0, 1, 0}},
		render.Vertex{pos = {660, 500}, color = {0, 0, 1}},
	)
}
