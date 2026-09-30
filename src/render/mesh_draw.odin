package render

import "../fb"
import m "../math"
import "../mesh"

// Map a normal to RGB: n in [-1,1] -> [0,1]. A geometry debug view; real
// shading is step 09+.
normal_color :: proc(n: m.Vec3) -> m.Vec3 {
	return n * 0.5 + m.Vec3{0.5, 0.5, 0.5}
}

// Filled, colored by normal, perspective-correct, depth-tested.
draw_mesh :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, mh: ^mesh.Mesh, width, height: int) {
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		triangle3(f, mvp,
			Vertex3{pos = mh.positions[a], color = normal_color(mh.normals[a]), uv = mh.uvs[a]},
			Vertex3{pos = mh.positions[b], color = normal_color(mh.normals[b]), uv = mh.uvs[b]},
			Vertex3{pos = mh.positions[c], color = normal_color(mh.normals[c]), uv = mh.uvs[c]},
			nil, true, width, height)
		i += 3
	}
}

// Filled, textured with perspective-correct UVs.
draw_mesh_textured :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, mh: ^mesh.Mesh, tex: ^Texture, width, height: int) {
	white := m.Vec3{1, 1, 1}
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		triangle3(f, mvp,
			Vertex3{pos = mh.positions[a], color = white, uv = mh.uvs[a]},
			Vertex3{pos = mh.positions[b], color = white, uv = mh.uvs[b]},
			Vertex3{pos = mh.positions[c], color = white, uv = mh.uvs[c]},
			tex, true, width, height)
		i += 3
	}
}

// Wireframe: project each triangle and draw its three edges (ignores depth).
draw_wire :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, mh: ^mesh.Mesh, col: fb.Color, width, height: int) {
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		pa, oka := project(mvp, Vertex3{pos = mh.positions[a]}, width, height)
		pb, okb := project(mvp, Vertex3{pos = mh.positions[b]}, width, height)
		pc, okc := project(mvp, Vertex3{pos = mh.positions[c]}, width, height)
		if oka && okb && okc {
			line(f, pa.pos.x, pa.pos.y, pb.pos.x, pb.pos.y, col)
			line(f, pb.pos.x, pb.pos.y, pc.pos.x, pc.pos.y, col)
			line(f, pc.pos.x, pc.pos.y, pa.pos.x, pa.pos.y, col)
		}
		i += 3
	}
}
