package main

import "core:fmt"
import "fb"
import "utils"

WIDTH  :: 800
HEIGHT :: 600

main :: proc() {
	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	// Step 02: render one frame and dump it to disk — proves the
	// CPU-buffer -> file path, independent of any window.
	draw_test_gradient(&f)
	if utils.write_ppm(&f, "gradient.ppm") {
		fmt.println("wrote gradient.ppm")
	}
	if utils.write_png(&f, "gradient.png") {
		fmt.println("wrote gradient.png")
	}

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}

		draw_test_gradient(&f)
		display.present(&display, &f)
	}
}

draw_test_gradient :: proc(f: ^fb.Framebuffer) {
	for y in 0 ..< f.height {
		for x in 0 ..< f.width {
			fb.set(f, x, y, fb.Color{
				r = u8(255 * x / f.width),
				g = u8(255 * y / f.height),
				b = 64,
				a = 255,
			})
		}
	}
}
