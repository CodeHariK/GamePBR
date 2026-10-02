package mesh

import "core:testing"
import m "../math"

// a single quad -> 4 vertices, 2 triangles; no normals in the file, so they're
// computed (the quad lies in z=0, wound CCW, so the normal is +z).
@(test)
test_obj_quad :: proc(t: ^testing.T) {
	src := "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n"
	mh := parse_obj(src)
	defer destroy(&mh)
	testing.expect_value(t, len(mh.positions), 4)
	testing.expect_value(t, len(mh.indices), 6)
	n := m.normalize(mh.normals[0])
	testing.expect(t, abs(n.z - 1) < 1e-5 && abs(n.x) < 1e-5 && abs(n.y) < 1e-5)
}

// two triangles sharing an edge, identical v/vt/vn -> vertices are deduped, so
// 4 unique vertices, not 6.
@(test)
test_obj_dedup :: proc(t: ^testing.T) {
	src := "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3\nf 1 3 4\n"
	mh := parse_obj(src)
	defer destroy(&mh)
	testing.expect_value(t, len(mh.positions), 4)
	testing.expect_value(t, len(mh.indices), 6)
}

// file-provided normals are kept, not recomputed.
@(test)
test_obj_reads_normals :: proc(t: ^testing.T) {
	src := "v 0 0 0\nv 1 0 0\nv 0 1 0\nvn 0 0 1\nf 1//1 2//1 3//1\n"
	mh := parse_obj(src)
	defer destroy(&mh)
	testing.expect_value(t, len(mh.positions), 3)
	testing.expect(t, abs(mh.normals[0].z - 1) < 1e-6)
}

@(test)
test_tangents_plane :: proc(t: ^testing.T) {
	mh := make_plane(1, 1)
	defer destroy(&mh)
	compute_tangents(&mh)
	tan := mh.tangents[0]
	// uv +u runs along +x, so the tangent should point ~+x and be perpendicular
	// to the +z normal.
	testing.expect(t, tan.x > 0.9 && abs(m.dot(tan, mh.normals[0])) < 1e-5)
}
