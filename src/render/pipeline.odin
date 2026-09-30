package render

import "../fb"
import m "../math"

// A model-space vertex fed into the projection pipeline.
Vertex3 :: struct {
	pos:   m.Vec3, // model space
	color: m.Vec3, // linear 0..1
}

// Project a model-space point through the MVP to a screen-space Vertex:
//   clip = mvp * (pos, 1)          homogeneous clip space
//   ndc  = clip.xyz / clip.w       perspective divide -> [-1,1] (z in [0,1])
//   xy   = viewport map            NDC -> pixels (y flipped: NDC up, screen down)
// Returns false when the point is behind the camera (w <= 0); the caller drops
// such triangles (proper near-plane clipping comes later).
project :: proc(mvp: m.Mat4, v: Vertex3, width, height: int) -> (Vertex, bool) {
	clip := mvp * m.Vec4{v.pos.x, v.pos.y, v.pos.z, 1}
	if clip.w <= 0 {
		return {}, false
	}
	inv_w := 1.0 / clip.w
	ndc := m.Vec3{clip.x * inv_w, clip.y * inv_w, clip.z * inv_w}

	sx := (ndc.x * 0.5 + 0.5) * f32(width)
	sy := (1.0 - (ndc.y * 0.5 + 0.5)) * f32(height) // flip y: NDC up -> screen down

	return Vertex{pos = {sx, sy, ndc.z}, color = v.color}, true
}

// Transform a model-space triangle by mvp and rasterize it (with the z-test).
triangle3 :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, a, b, c: Vertex3, width, height: int) {
	sa, oka := project(mvp, a, width, height)
	sb, okb := project(mvp, b, width, height)
	sc, okc := project(mvp, c, width, height)
	if !oka || !okb || !okc {
		return // crude: drop any triangle with a vertex behind the camera
	}
	triangle(f, sa, sb, sc)
}
