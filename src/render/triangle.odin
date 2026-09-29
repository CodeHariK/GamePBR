package render

import "core:math"
import "../fb"
import m "../math"

// A vertex for the rasterizer: screen-space pixel position + a linear color.
// (Depth, UVs, and normals arrive in later steps.)
Vertex :: struct {
	pos:   m.Vec2, // pixel coordinates, origin top-left
	color: m.Vec3, // linear 0..1
}

// Edge function: twice the signed area of triangle (a, b, p). Its sign says
// which side of the directed line a->b the point p lies on; swept across the
// triangle it also yields the barycentric weights. This one function is the
// whole rasterizer.
edge :: proc(a, b, p: m.Vec2) -> f32 {
	return (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x)
}

// Barycentric coordinates of p within triangle (a, b, c). Caller ensures the
// triangle isn't degenerate (area != 0). l0/l1/l2 weight a/b/c and sum to 1.
barycentric :: proc(a, b, c, p: m.Vec2) -> (l0, l1, l2: f32) {
	area := edge(a, b, c)
	l0 = edge(b, c, p) / area
	l1 = edge(c, a, p) / area
	l2 = edge(a, b, p) / area
	return
}

// Fill a triangle, interpolating the vertex colors across it (Gouraud shading).
triangle :: proc(f: ^fb.Framebuffer, a, b, c: Vertex) {
	area := edge(a.pos, b.pos, c.pos)
	if area == 0 {
		return // degenerate: nothing to fill
	}
	inv_area := 1.0 / area

	// Bounding box of the triangle, clamped to the framebuffer, so we only
	// test pixels that could possibly be covered.
	minx := clamp(int(math.floor(min(a.pos.x, min(b.pos.x, c.pos.x)))), 0, f.width  - 1)
	maxx := clamp(int(math.ceil (max(a.pos.x, max(b.pos.x, c.pos.x)))), 0, f.width  - 1)
	miny := clamp(int(math.floor(min(a.pos.y, min(b.pos.y, c.pos.y)))), 0, f.height - 1)
	maxy := clamp(int(math.ceil (max(a.pos.y, max(b.pos.y, c.pos.y)))), 0, f.height - 1)

	for y in miny ..= maxy {
		for x in minx ..= maxx {
			p := m.Vec2{f32(x) + 0.5, f32(y) + 0.5} // sample at the pixel center

			w0 := edge(b.pos, c.pos, p)
			w1 := edge(c.pos, a.pos, p)
			w2 := edge(a.pos, b.pos, p)

			// Inside when all three edges share the triangle's winding sign.
			inside := (w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0)
			if !inside {
				continue
			}

			l0 := w0 * inv_area
			l1 := w1 * inv_area
			l2 := w2 * inv_area

			col := a.color * l0 + b.color * l1 + c.color * l2
			fb.set(f, x, y, fb.Color{
				r = u8(m.saturate(col.x) * 255),
				g = u8(m.saturate(col.y) * 255),
				b = u8(m.saturate(col.z) * 255),
				a = 255,
			})
		}
	}
}
