package render

import "core:math"
import "../fb"
import m "../math"

// A screen-space vertex. Besides screen position + depth, it carries everything
// the pipeline interpolates perspective-correctly: color, uv, world-space normal
// and tangent, and inv_w (= 1/clip.w).
Vertex :: struct {
	pos:     m.Vec3,
	color:   m.Vec3,
	uv:      m.Vec2,
	normal:  m.Vec3,
	tangent: m.Vec3,
	inv_w:   f32,
}

edge :: proc(a, b, p: m.Vec2) -> f32 {
	return (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x)
}

barycentric :: proc(a, b, c, p: m.Vec2) -> (l0, l1, l2: f32) {
	area := edge(a, b, c)
	l0 = edge(b, c, p) / area
	l1 = edge(c, a, p) / area
	l2 = edge(a, b, p) / area
	return
}

// Affine 2D screen-space fill with linear color interpolation + depth test.
// (3D geometry uses the perspective-correct path in pipeline.odin.)
triangle :: proc(f: ^fb.Framebuffer, a, b, c: Vertex) {
	area := edge(a.pos.xy, b.pos.xy, c.pos.xy)
	if area == 0 { return }
	inv_area := 1.0 / area

	minx := clamp(int(math.floor(min(a.pos.x, min(b.pos.x, c.pos.x)))), 0, f.width  - 1)
	maxx := clamp(int(math.ceil (max(a.pos.x, max(b.pos.x, c.pos.x)))), 0, f.width  - 1)
	miny := clamp(int(math.floor(min(a.pos.y, min(b.pos.y, c.pos.y)))), 0, f.height - 1)
	maxy := clamp(int(math.ceil (max(a.pos.y, max(b.pos.y, c.pos.y)))), 0, f.height - 1)

	for y in miny ..= maxy {
		for x in minx ..= maxx {
			p := m.Vec2{f32(x) + 0.5, f32(y) + 0.5}
			w0 := edge(b.pos.xy, c.pos.xy, p)
			w1 := edge(c.pos.xy, a.pos.xy, p)
			w2 := edge(a.pos.xy, b.pos.xy, p)
			inside := (w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0)
			if !inside { continue }
			l0 := w0 * inv_area; l1 := w1 * inv_area; l2 := w2 * inv_area
			z := l0 * a.pos.z + l1 * b.pos.z + l2 * c.pos.z
			idx := y * f.width + x
			if z >= f.depth[idx] { continue }
			f.depth[idx] = z
			col := a.color * l0 + b.color * l1 + c.color * l2
			f.pixels[idx] = fb.Color{
				r = u8(m.saturate(col.x) * 255),
				g = u8(m.saturate(col.y) * 255),
				b = u8(m.saturate(col.z) * 255),
				a = 255,
			}
		}
	}
}
