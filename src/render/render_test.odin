package render

import "core:testing"
import "../fb"
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

// A near triangle drawn FIRST must survive a far triangle drawn OVER it —
// that draw-order independence is the whole point of a depth buffer.
@(test)
test_depth_occludes :: proc(t: ^testing.T) {
	f := fb.create(10, 10)
	defer fb.destroy(&f)
	fb.clear(&f, fb.Color{0, 0, 0, 255})
	fb.clear_depth(&f, 1.0)

	// a big triangle that covers the whole 10x10, near (z=0.2), blue
	triangle(&f,
		Vertex{pos = {-100, -100, 0.2}, color = {0, 0, 1}},
		Vertex{pos = { 300, -100, 0.2}, color = {0, 0, 1}},
		Vertex{pos = {-100,  300, 0.2}, color = {0, 0, 1}},
	)
	// same coverage, far (z=0.8), red — must be rejected by the z-test
	triangle(&f,
		Vertex{pos = {-100, -100, 0.8}, color = {1, 0, 0}},
		Vertex{pos = { 300, -100, 0.8}, color = {1, 0, 0}},
		Vertex{pos = {-100,  300, 0.8}, color = {1, 0, 0}},
	)

	px := f.pixels[5 * 10 + 5] // center pixel
	testing.expect(t, px.b > 200 && px.r < 50) // still blue: far red was rejected
}
