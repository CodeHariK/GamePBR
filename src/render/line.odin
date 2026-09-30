package render

import "../fb"

// Bresenham line in screen space (integer, no anti-aliasing). Used for
// wireframe; ignores depth.
line :: proc(f: ^fb.Framebuffer, x0f, y0f, x1f, y1f: f32, c: fb.Color) {
	x0 := int(x0f); y0 := int(y0f)
	x1 := int(x1f); y1 := int(y1f)
	dx := abs(x1 - x0)
	dy := -abs(y1 - y0)
	sx := x0 < x1 ? 1 : -1
	sy := y0 < y1 ? 1 : -1
	err := dx + dy
	for {
		fb.set(f, x0, y0, c)
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
	}
}
