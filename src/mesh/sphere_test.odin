package mesh

import "core:testing"
import m "../math"

// make_sphere(radius, segments, rings) produces (rings+1)*(segments+1) vertices
// and rings*segments*6 indices (two triangles per quad).
@(test)
test_sphere_counts :: proc(t: ^testing.T) {
	s := make_sphere(2.0, 8, 6)
	defer destroy(&s)
	testing.expect_value(t, len(s.positions), 7 * 9)
	testing.expect_value(t, len(s.normals), 7 * 9)
	testing.expect_value(t, len(s.indices), 6 * 8 * 6)
}

// Every vertex sits on the sphere (|p| == radius) and its normal is the
// outward radial direction (normalize(p)).
@(test)
test_sphere_on_surface :: proc(t: ^testing.T) {
	r: f32 = 2.0
	s := make_sphere(r, 16, 12)
	defer destroy(&s)
	for p, i in s.positions {
		testing.expect(t, abs(m.length(p) - r) < 1e-4)
		n := m.normalize(p)
		d := s.normals[i] - n
		testing.expect(t, abs(d.x) < 1e-4 && abs(d.y) < 1e-4 && abs(d.z) < 1e-4)
	}
}
