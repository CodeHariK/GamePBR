package render

import "../fb"
import m "../math"
import "../mesh"

// Map a normal to RGB: n in [-1,1] -> [0,1].
normal_color :: proc(n: m.Vec3) -> m.Vec3 {
	return n * 0.5 + m.Vec3{0.5, 0.5, 0.5}
}

// Filled, colored by the WORLD-space geometric normal (shifts as the model
// rotates — confirming normals are in world space, not object space).
draw_mesh :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, model: m.Mat4, mh: ^mesh.Mesh, width, height: int) {
	nrm := m.normal_matrix(model)
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		ca := normal_color(m.normalize(nrm * mh.normals[a]))
		cb := normal_color(m.normalize(nrm * mh.normals[b]))
		cc := normal_color(m.normalize(nrm * mh.normals[c]))
		triangle3(f, mvp,
			Vertex3{pos = mh.positions[a], color = ca, uv = mh.uvs[a]},
			Vertex3{pos = mh.positions[b], color = cb, uv = mh.uvs[b]},
			Vertex3{pos = mh.positions[c], color = cc, uv = mh.uvs[c]},
			nil, nil, true, width, height)
		i += 3
	}
}

// Filled, textured (albedo) with perspective-correct UVs.
draw_mesh_textured :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, mh: ^mesh.Mesh, tex: ^Texture, width, height: int) {
	white := m.Vec3{1, 1, 1}
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		triangle3(f, mvp,
			Vertex3{pos = mh.positions[a], color = white, uv = mh.uvs[a]},
			Vertex3{pos = mh.positions[b], color = white, uv = mh.uvs[b]},
			Vertex3{pos = mh.positions[c], color = white, uv = mh.uvs[c]},
			tex, nil, true, width, height)
		i += 3
	}
}

// Normal-mapped: builds world N/T per vertex, the pipeline builds the TBN per
// pixel, samples the normal map, and outputs the perturbed world normal as color.
draw_mesh_normalmapped :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, model: m.Mat4, mh: ^mesh.Mesh, nmap: ^Texture, width, height: int) {
	nrm := m.normal_matrix(model)
	m3 := m.mat3_from_mat4(model)
	wn :: proc(nrm: m.Mat3, n: m.Vec3) -> m.Vec3 { return m.normalize(nrm * n) }
	wt :: proc(m3: m.Mat3, t: m.Vec3) -> m.Vec3 { return m.normalize(m3 * t) }
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		triangle3(f, mvp,
			Vertex3{pos = mh.positions[a], uv = mh.uvs[a], normal = wn(nrm, mh.normals[a]), tangent = wt(m3, mh.tangents[a])},
			Vertex3{pos = mh.positions[b], uv = mh.uvs[b], normal = wn(nrm, mh.normals[b]), tangent = wt(m3, mh.tangents[b])},
			Vertex3{pos = mh.positions[c], uv = mh.uvs[c], normal = wn(nrm, mh.normals[c]), tangent = wt(m3, mh.tangents[c])},
			nil, nmap, true, width, height)
		i += 3
	}
}

// Lit: world-space normals (via the normal matrix), tangents and positions (via
// `model`) are handed to the fragment stage, which evaluates the shading model
// chosen by sh.model (Baseline or PBR) per pixel, with any maps in sh.
draw_mesh_lit :: proc(f: ^fb.Framebuffer, mvp: m.Mat4, model: m.Mat4, mh: ^mesh.Mesh, sh: ShadeCtx, width, height: int) {
	nrm := m.normal_matrix(model)
	m3 := m.mat3_from_mat4(model)
	ctx := sh
	wpos :: proc(model: m.Mat4, p: m.Vec3) -> m.Vec3 {
		w := model * m.Vec4{p.x, p.y, p.z, 1}
		return m.Vec3{w.x, w.y, w.z}
	}
	// Tangents are optional: only meshes that ran compute_tangents have them,
	// and only a ctx with nrm_tex reads them.
	vert :: proc(mh: ^mesh.Mesh, nrm, m3: m.Mat3, model: m.Mat4, i: int) -> Vertex3 {
		t := i < len(mh.tangents) ? m.normalize(m3 * mh.tangents[i]) : m.Vec3{}
		return Vertex3{
			pos       = mh.positions[i],
			world_pos = wpos(model, mh.positions[i]),
			uv        = mh.uvs[i],
			normal    = m.normalize(nrm * mh.normals[i]),
			tangent   = t,
		}
	}
	i := 0
	for i < len(mh.indices) {
		a := int(mh.indices[i]); b := int(mh.indices[i + 1]); c := int(mh.indices[i + 2])
		triangle3(f, mvp, vert(mh, nrm, m3, model, a), vert(mh, nrm, m3, model, b), vert(mh, nrm, m3, model, c),
			nil, nil, true, width, height, &ctx)
		i += 3
	}
}

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
