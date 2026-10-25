package render

import "core:math"
import "../fb"
import m "../math"

// World-space direction of the ray through pixel (x, y) — the inverse of what
// the projection does to geometry. Built from the camera basis rather than by
// inverting the 4×4 matrix: forward, right, up, scaled by the field of view.
camera_ray :: proc(c: Camera, x, y: f32, width, height: int) -> m.Vec3 {
	fwd := m.normalize(c.target - c.eye)
	right := m.normalize(m.cross(fwd, c.up))
	up := m.cross(right, fwd)
	ndc_x := 2 * (x + 0.5) / f32(width) - 1
	ndc_y := 1 - 2 * (y + 0.5) / f32(height) // pixel rows grow downward
	th := math.tan(c.fov_y * 0.5)
	return m.normalize(fwd + right * (ndc_x * th * c.aspect) + up * (ndc_y * th))
}

// Fill the frame with the environment as seen by the camera — the sky behind
// the scene. Writes HDR radiance (and the legacy clamped pixel); leaves depth at
// the far plane so geometry drawn afterwards covers it.
draw_env_background :: proc(f: ^fb.Framebuffer, c: Camera, env: ^EnvMap) {
	for y in 0 ..< f.height {
		for x in 0 ..< f.width {
			L := env_sample(env, camera_ray(c, f32(x), f32(y), f.width, f.height))
			i := y * f.width + x
			f.hdr[i] = L
			f.pixels[i] = fb.Color{
				u8(m.saturate(L.x) * 255), u8(m.saturate(L.y) * 255), u8(m.saturate(L.z) * 255), 255,
			}
		}
	}
}
