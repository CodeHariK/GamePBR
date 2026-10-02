package mesh

import m "../math"

// An indexed triangle mesh. Parallel attribute arrays (one entry per unique
// vertex) plus a flat index list, three indices per triangle.
Mesh :: struct {
	positions: [dynamic]m.Vec3,
	normals:   [dynamic]m.Vec3,
	uvs:       [dynamic]m.Vec2,
	tangents:  [dynamic]m.Vec3, // filled by compute_tangents (for normal mapping)
	indices:   [dynamic]u32,
}

destroy :: proc(mh: ^Mesh) {
	delete(mh.positions)
	delete(mh.normals)
	delete(mh.uvs)
	delete(mh.tangents)
	delete(mh.indices)
	mh^ = {}
}

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

// Smooth, area-weighted vertex normals from the triangles (used when the file
// provides none).
compute_normals :: proc(mh: ^Mesh) {
	for i in 0 ..< len(mh.normals) {
		mh.normals[i] = m.Vec3{}
	}
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
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

// Per-vertex tangents in the +U direction of the texture, solved from positions
// and UVs, then Gram-Schmidt orthonormalized against the normal. Needed to build
// the TBN basis for normal mapping. Requires normals and uvs to be present.
compute_tangents :: proc(mh: ^Mesh) {
	resize(&mh.tangents, len(mh.positions))
	for i in 0 ..< len(mh.tangents) {
		mh.tangents[i] = m.Vec3{}
	}
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		e1 := mh.positions[b] - mh.positions[a]
		e2 := mh.positions[c] - mh.positions[a]
		du1 := mh.uvs[b].x - mh.uvs[a].x; dv1 := mh.uvs[b].y - mh.uvs[a].y
		du2 := mh.uvs[c].x - mh.uvs[a].x; dv2 := mh.uvs[c].y - mh.uvs[a].y
		denom := du1 * dv2 - du2 * dv1
		r := denom != 0 ? 1.0 / denom : 0.0
		t := (e1 * dv2 - e2 * dv1) * r
		mh.tangents[a] += t
		mh.tangents[b] += t
		mh.tangents[c] += t
		i += 3
	}
	for i in 0 ..< len(mh.tangents) {
		n := mh.normals[i]
		t := mh.tangents[i]
		t = t - n * m.dot(n, t) // orthogonalize against the normal
		mh.tangents[i] = m.normalize(t)
	}
}

// A flat quad in the XY plane facing +Z, UVs 0..uv_tiles. Handy for showing a
// material on a flat surface.
make_plane :: proc(half: f32, uv_tiles: f32) -> Mesh {
	mh: Mesh
	append(&mh.positions,
		m.Vec3{-half, -half, 0}, m.Vec3{half, -half, 0},
		m.Vec3{half, half, 0}, m.Vec3{-half, half, 0})
	for _ in 0 ..< 4 {
		append(&mh.normals, m.Vec3{0, 0, 1})
	}
	append(&mh.uvs,
		m.Vec2{0, 0}, m.Vec2{uv_tiles, 0},
		m.Vec2{uv_tiles, uv_tiles}, m.Vec2{0, uv_tiles})
	append(&mh.indices, 0, 1, 2, 0, 2, 3)
	return mh
}
