package render

import "core:testing"
import m "../math"

// triangle (0,0)-(6,0)-(0,6): centroid is (2,2) with equal weights.
@(test)
test_barycentric_centroid :: proc(t: ^testing.T) {
	a := m.Vec2{0, 0}; b := m.Vec2{6, 0}; c := m.Vec2{0, 6}
	l0, l1, l2 := barycentric(a, b, c, m.Vec2{2, 2})
	testing.expect(t, abs(l0 - 1.0/3) < 1e-5)
	testing.expect(t, abs(l1 - 1.0/3) < 1e-5)
	testing.expect(t, abs(l2 - 1.0/3) < 1e-5)
}

// at vertex a, the weight of a is 1 and the others 0.
@(test)
test_barycentric_at_vertex :: proc(t: ^testing.T) {
	a := m.Vec2{0, 0}; b := m.Vec2{6, 0}; c := m.Vec2{0, 6}
	l0, l1, l2 := barycentric(a, b, c, a)
	testing.expect(t, abs(l0 - 1) < 1e-5)
	testing.expect(t, abs(l1) < 1e-5)
	testing.expect(t, abs(l2) < 1e-5)
}

// points on opposite sides of a directed edge get opposite signs.
@(test)
test_edge_opposite_sides :: proc(t: ^testing.T) {
	a := m.Vec2{0, 0}; b := m.Vec2{4, 0}
	below := edge(a, b, m.Vec2{2,  1})
	above := edge(a, b, m.Vec2{2, -1})
	testing.expect(t, (below > 0) != (above > 0))
}
