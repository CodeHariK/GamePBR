package render

import "../fb"
import m "../math"
import "../mesh"

// Map a normal to an RGB color: n in [-1,1] -> [0,1]. A geometry debug view
// that confirms normals loaded/computed correctly. Real shading is step 09+.
normal_color :: proc(n: m.Vec3) -> m.Vec3 {
	return n * 0.5 + m.Vec3{0.5, 0.5, 0.5}
}

// Filled, normal-colored, depth-tested.
draw_mesh :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, mh: ^mesh.Mesh, width, height: int) {
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		triangle3(f, mvp,
			Vertex3{mh.positions[a], normal_color(mh.normals[a])},
			Vertex3{mh.positions[b], normal_color(mh.normals[b])},
			Vertex3{mh.positions[c], normal_color(mh.normals[c])},
			width, height)
		i += 3
	}
}

// Wireframe: project each triangle and draw its three edges.
draw_wire :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, mh: ^mesh.Mesh, col: fb.Color, width, height: int) {
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		pa, oka := project(mvp, Vertex3{mh.positions[a], m.Vec3{}}, width, height)
		pb, okb := project(mvp, Vertex3{mh.positions[b], m.Vec3{}}, width, height)
		pc, okc := project(mvp, Vertex3{mh.positions[c], m.Vec3{}}, width, height)
		if oka && okb && okc {
			line(f, pa.pos.x, pa.pos.y, pb.pos.x, pb.pos.y, col)
			line(f, pb.pos.x, pb.pos.y, pc.pos.x, pc.pos.y, col)
			line(f, pc.pos.x, pc.pos.y, pa.pos.x, pa.pos.y, col)
		}
		i += 3
	}
}
