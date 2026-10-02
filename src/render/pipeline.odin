package render

import "core:math"
import "../fb"
import m "../math"

// A model-space vertex fed into the pipeline. normal/tangent are expected in
// WORLD space already (the draw procs transform them); only pos is projected.
Vertex3 :: struct {
	pos:       m.Vec3, // model space (projected by mvp)
	world_pos: m.Vec3, // world space (set by lit draw procs; for view vector)
	color:     m.Vec3,
	uv:        m.Vec2,
	normal:    m.Vec3,
	tangent:   m.Vec3,
}

project :: proc(mvp: m.Mat4, v: Vertex3, width, height: int) -> (Vertex, bool) {
	clip := mvp * m.Vec4{v.pos.x, v.pos.y, v.pos.z, 1}
	if clip.w <= 0 {
		return {}, false
	}
	iw := 1.0 / clip.w
	ndc := m.Vec3{clip.x * iw, clip.y * iw, clip.z * iw}
	sx := (ndc.x * 0.5 + 0.5) * f32(width)
	sy := (1.0 - (ndc.y * 0.5 + 0.5)) * f32(height)
	return Vertex{
		pos = {sx, sy, ndc.z}, world_pos = v.world_pos, color = v.color, uv = v.uv,
		normal = v.normal, tangent = v.tangent, inv_w = iw,
	}, true
}

// Project + rasterize a 3D triangle. Shading at each pixel, highest priority first:
//   shade != nil -> Lambert + Blinn-Phong lighting (albedo from shade.tex or mat)
//   nmap  != nil -> tangent-space normal mapping, output = normal visualization
//   tex   != nil -> sample albedo texture
//   else         -> interpolated vertex color
triangle3 :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, va, vb, vc: Vertex3, tex, nmap: ^Texture, correct: bool, width, height: int, shade: ^ShadeCtx = nil) {
	a, oka := project(mvp, va, width, height)
	b, okb := project(mvp, vb, width, height)
	c, okc := project(mvp, vc, width, height)
	if !oka || !okb || !okc {
		return
	}
	fill(f, a, b, c, tex, nmap, correct, shade)
}

@(private)
fill :: proc(f: ^fb.Framebuffer, a, b, c: Vertex, tex, nmap: ^Texture, correct: bool, shade: ^ShadeCtx = nil) {
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

			// Perspective-correct barycentric weights (weight by 1/w, then divide).
			wa := l0 * a.inv_w; wb := l1 * b.inv_w; wc := l2 * c.inv_w
			cw := correct ? 1.0 / (wa + wb + wc) : 1.0
			if !correct { wa = l0; wb = l1; wc = l2 } // affine fallback

			u := (a.uv.x * wa + b.uv.x * wb + c.uv.x * wc) * cw
			v := (a.uv.y * wa + b.uv.y * wb + c.uv.y * wc) * cw

			col: m.Vec3
			if shade != nil {
				N := m.normalize((a.normal * wa + b.normal * wb + c.normal * wc) * cw)
				wp := (a.world_pos * wa + b.world_pos * wb + c.world_pos * wc) * cw
				V := m.normalize(shade.eye - wp)
				albedo := shade.mat.albedo
				if shade.tex != nil { albedo = sample(shade.tex, u, v) }
				col = shade_blinn_phong(shade.mat, shade.light, N, V, albedo, shade.ambient)
			} else if nmap != nil {
				N := m.normalize((a.normal * wa + b.normal * wb + c.normal * wc) * cw)
				T := (a.tangent * wa + b.tangent * wb + c.tangent * wc) * cw
				T = m.normalize(T - N * m.dot(N, T)) // re-orthonormalize
				B := m.cross(N, T)
				sn := sample_normal(nmap, u, v)          // tangent-space normal
				wn := m.normalize(sn.x * T + sn.y * B + sn.z * N) // -> world space
				col = normal_color(wn)
			} else if tex != nil {
				col = sample(tex, u, v)
			} else {
				col = (a.color * wa + b.color * wb + c.color * wc) * cw
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
