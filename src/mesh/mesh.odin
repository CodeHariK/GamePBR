package mesh

import m "../math"

// An indexed triangle mesh. Parallel attribute arrays (one entry per unique
// vertex) plus a flat index list, three indices per triangle. This is the
// loader-agnostic type every format (OBJ now, glTF later) produces.
Mesh :: struct {
	positions: [dynamic]m.Vec3,
	normals:   [dynamic]m.Vec3,
	uvs:       [dynamic]m.Vec2,
	indices:   [dynamic]u32, // 3 per triangle, into the arrays above
}

destroy :: proc(mh: ^Mesh) {
	delete(mh.positions)
	delete(mh.normals)
	delete(mh.uvs)
	delete(mh.indices)
	mh^ = {}
}

// Axis-aligned bounding box of the mesh (for centering / scaling to view).
bounds :: proc(mh: ^Mesh) -> (lo, hi: m.Vec3) {
	if len(mh.positions) == 0 {
		return
	}
	lo = mh.positions[0]
	hi = mh.positions[0]
	for p in mh.positions {
		lo = m.Vec3{min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)}
		hi = m.Vec3{max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)}
	}
	return
}

// Recompute smooth (area-weighted) vertex normals from the triangles. Used when
// the source file didn't provide any.
compute_normals :: proc(mh: ^Mesh) {
	for i in 0 ..< len(mh.normals) {
		mh.normals[i] = m.Vec3{}
	}
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		// un-normalized cross product is proportional to the face area, so
		// simply summing gives an area-weighted average.
		n := m.cross(mh.positions[b] - mh.positions[a], mh.positions[c] - mh.positions[a])
		mh.normals[a] += n
		mh.normals[b] += n
		mh.normals[c] += n
		i += 3
	}
	for i in 0 ..< len(mh.normals) {
		mh.normals[i] = m.normalize(mh.normals[i])
	}
}
