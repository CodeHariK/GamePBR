package render

import "core:math"
import "core:testing"
import m "../math"

// Facing the light head-on with specular off: pure Lambert returns albedo
// (N·L = 1), plus the (here zero) ambient term.
@(test)
test_diffuse_head_on :: proc(t: ^testing.T) {
	light := DirLight{dir = {0, 0, -1}, color = {1, 1, 1}, intensity = 1} // L = +Z
	mat := Material{albedo = {0.5, 0.5, 0.5}, specular = {0, 0, 0}, shininess = 1}
	c := shade_blinn_phong(mat, light, m.Vec3{0, 0, 1}, m.Vec3{0, 0, 1}, mat.albedo, m.Vec3{0, 0, 0})
	testing.expect(t, abs(c.x - 0.5) < 1e-5 && abs(c.y - 0.5) < 1e-5 && abs(c.z - 0.5) < 1e-5)
}

// A surface turned away from the light gets no diffuse and no specular: the
// max(N·L, 0) clamp drives everything to the ambient floor (zero here).
@(test)
test_backface_dark :: proc(t: ^testing.T) {
	light := DirLight{dir = {0, 0, 1}, color = {1, 1, 1}, intensity = 1} // L = -Z (behind)
	mat := Material{albedo = {0.8, 0.8, 0.8}, specular = {1, 1, 1}, shininess = 32}
	c := shade_blinn_phong(mat, light, m.Vec3{0, 0, 1}, m.Vec3{0, 0, 1}, mat.albedo, m.Vec3{0, 0, 0})
	testing.expect(t, c.x < 1e-6 && c.y < 1e-6 && c.z < 1e-6)
}

// Ambient is a flat floor: even fully lit, output never drops below ambient*albedo.
@(test)
test_ambient_floor :: proc(t: ^testing.T) {
	light := DirLight{dir = {0, 0, 1}, color = {1, 1, 1}, intensity = 1} // behind -> no direct
	mat := Material{albedo = {1, 0.5, 0.25}, specular = {0, 0, 0}, shininess = 1}
	amb := m.Vec3{0.1, 0.1, 0.1}
	c := shade_blinn_phong(mat, light, m.Vec3{0, 0, 1}, m.Vec3{0, 0, 1}, mat.albedo, amb)
	testing.expect(t, abs(c.x - 0.1) < 1e-5 && abs(c.y - 0.05) < 1e-5 && abs(c.z - 0.025) < 1e-5)
}

// The Blinn-Phong highlight is maximal when the half-vector aligns with N
// (H = N <=> N·H = 1), and falls off as the view tilts away from the mirror
// direction. albedo = 0 isolates the specular lobe.
@(test)
test_specular_peak :: proc(t: ^testing.T) {
	light := DirLight{dir = {0, 0, -1}, color = {1, 1, 1}, intensity = 1} // L = +Z
	mat := Material{albedo = {0, 0, 0}, specular = {1, 1, 1}, shininess = 32}
	N := m.Vec3{0, 0, 1}

	peak := shade_blinn_phong(mat, light, N, m.Vec3{0, 0, 1}, mat.albedo, m.Vec3{0, 0, 0})
	tilt := math.to_radians_f32(30)
	Vt := m.normalize(m.Vec3{math.sin(tilt), 0, math.cos(tilt)})
	off := shade_blinn_phong(mat, light, N, Vt, mat.albedo, m.Vec3{0, 0, 0})

	testing.expect(t, abs(peak.x - 1) < 1e-5) // N·H = 1 -> full specular
	testing.expect(t, off.x < peak.x)         // tilt lowers the highlight
}
