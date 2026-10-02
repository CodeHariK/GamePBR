package mesh

import "core:math"
import m "../math"

// A UV sphere: `rings` latitude bands (pole to pole) by `segments` longitude
// slices. For a unit-radius sphere the position of each vertex is also its
// normal, which makes it the cleanest surface to test a shading model on —
// every normal direction on the hemisphere is present and smoothly varying.
//
// UVs: u = longitude (0..1 around), v = latitude (0..1 top..bottom).
make_sphere :: proc(radius: f32, segments, rings: int) -> Mesh {
	mh: Mesh
	segs := max(segments, 3)
	rngs := max(rings, 2)

	for ring in 0 ..= rngs {
		v := f32(ring) / f32(rngs)
		phi := v * math.PI // 0 (top pole) .. PI (bottom pole)
		sp := math.sin(phi); cp := math.cos(phi)
		for seg in 0 ..= segs {
			u := f32(seg) / f32(segs)
			theta := u * 2.0 * math.PI
			n := m.Vec3{sp * math.cos(theta), cp, sp * math.sin(theta)}
			append(&mh.positions, n * radius)
			append(&mh.normals, n)
			append(&mh.uvs, m.Vec2{u, v})
		}
	}

	stride := segs + 1
	for ring in 0 ..< rngs {
		for seg in 0 ..< segs {
			i0 := u32(ring * stride + seg)
			i1 := u32(ring * stride + seg + 1)
			i2 := u32((ring + 1) * stride + seg)
			i3 := u32((ring + 1) * stride + seg + 1)
			append(&mh.indices, i0, i2, i1)
			append(&mh.indices, i1, i2, i3)
		}
	}
	return mh
}
