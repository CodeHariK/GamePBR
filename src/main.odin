package main

WIDTH  :: 800
HEIGHT :: 600

main :: proc() {
	fb := framebuffer_create(WIDTH, HEIGHT)
	defer framebuffer_destroy(&fb)

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}

		// Step 00 proof-of-life: a gradient so we know the CPU->screen
		// path works. Steps 03+ replace this with the rasterizer.
		draw_test_gradient(&fb)

		display.present(&display, &fb)
	}
}

draw_test_gradient :: proc(fb: ^Framebuffer) {
	for y in 0 ..< fb.height {
		for x in 0 ..< fb.width {
			framebuffer_set(fb, x, y, Color{
				r = u8(255 * x / fb.width),
				g = u8(255 * y / fb.height),
				b = 64,
				a = 255,
			})
		}
	}
}
