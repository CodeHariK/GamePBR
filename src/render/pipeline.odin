package render

import "core:math"
import "../fb"
import m "../math"

// A model-space vertex fed into the projection pipeline.
Vertex3 :: struct {
	pos:   m.Vec3, // model space
	color: m.Vec3, // linear 0..1
	uv:    m.Vec2,
}

// Project a model-space point to a screen-space Vertex, keeping inv_w = 1/clip.w
// for perspective-correct interpolation. Returns false if behind the camera.
project :: proc(mvp: m.Mat4, v: Vertex3, width, height: int) -> (Vertex, bool) {
	clip := mvp * m.Vec4{v.pos.x, v.pos.y, v.pos.z, 1}
	if clip.w <= 0 {
		return {}, false
	}
	iw := 1.0 / clip.w
	ndc := m.Vec3{clip.x * iw, clip.y * iw, clip.z * iw}
	sx := (ndc.x * 0.5 + 0.5) * f32(width)
	sy := (1.0 - (ndc.y * 0.5 + 0.5)) * f32(height)
	return Vertex{pos = {sx, sy, ndc.z}, color = v.color, uv = v.uv, inv_w = iw}, true
}

// Project and rasterize a 3D triangle. If tex != nil, sample it with the UVs;
// otherwise use interpolated vertex color. `correct` selects perspective-correct
// interpolation (true) vs affine (false) — the latter only exists to show, in
// the devlog, why perspective correction is needed.
triangle3 :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, va, vb, vc: Vertex3, tex: ^Texture, correct: bool, width, height: int) {
	a, oka := project(mvp, va, width, height)
	b, okb := project(mvp, vb, width, height)
	c, okc := project(mvp, vc, width, height)
	if !oka || !okb || !okc {
		return
	}
	fill(f, a, b, c, tex, correct)
}

@(private)
fill :: proc(f: ^fb.Framebuffer, a, b, c: Vertex, tex: ^Texture, correct: bool) {
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

			// Depth interpolates linearly in screen space (correct for the z-buffer).
			z := l0 * a.pos.z + l1 * b.pos.z + l2 * c.pos.z
			idx := y * f.width + x
			if z >= f.depth[idx] { continue }

			col: m.Vec3
			if correct {
				// Perspective-correct: weight attributes by 1/w, interpolate, divide.
				iw := l0 * a.inv_w + l1 * b.inv_w + l2 * c.inv_w
				cw := 1.0 / iw
				if tex != nil {
					u := (l0 * a.uv.x * a.inv_w + l1 * b.uv.x * b.inv_w + l2 * c.uv.x * c.inv_w) * cw
					v := (l0 * a.uv.y * a.inv_w + l1 * b.uv.y * b.inv_w + l2 * c.uv.y * c.inv_w) * cw
					col = sample(tex, u, v)
				} else {
					col = (a.color * (l0 * a.inv_w) + b.color * (l1 * b.inv_w) + c.color * (l2 * c.inv_w)) * cw
				}
			} else {
				// Affine: plain screen-space linear (wrong under perspective).
				if tex != nil {
					u := l0 * a.uv.x + l1 * b.uv.x + l2 * c.uv.x
					v := l0 * a.uv.y + l1 * b.uv.y + l2 * c.uv.y
					col = sample(tex, u, v)
				} else {
					col = a.color * l0 + b.color * l1 + c.color * l2
				}
			}

			f.depth[idx] = z
			f.pixels[idx] = fb.Color{
				r = u8(m.saturate(col.x) * 255),
				g = u8(m.saturate(col.y) * 255),
				b = u8(m.saturate(col.z) * 255),
				a = 255,
			}
		}
	}
}
