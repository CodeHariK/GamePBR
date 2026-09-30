package mesh

import "core:os"
import "core:strconv"
import "core:strings"
import m "../math"

// Read a Wavefront .obj file into a Mesh. Returns ok=false if the file can't
// be read.
load_obj :: proc(path: string) -> (Mesh, bool) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(data)
	return parse_obj(string(data)), true
}

@(private)
pf :: proc(s: string) -> f32 {
	v, _ := strconv.parse_f64(s)
	return f32(v)
}

@(private)
pint :: proc(s: string) -> int {
	v, _ := strconv.parse_int(s)
	return v
}

// Resolve a 1-based (or negative, end-relative) OBJ index to 0-based.
// Returns -1 for the "absent" index 0.
@(private)
obj_resolve :: proc(idx, count: int) -> int {
	if idx > 0 {
		return idx - 1
	}
	if idx < 0 {
		return count + idx
	}
	return -1
}

// Parse OBJ text. Handles v / vt / vn, polygonal faces (fan-triangulated), the
// v, v/vt, v//vn and v/vt/vn face-vertex forms, dedups unique triples into a
// GPU-style indexed mesh, and computes normals if the file has none.
parse_obj :: proc(src: string) -> Mesh {
	pv:  [dynamic]m.Vec3
	pvt: [dynamic]m.Vec2
	pvn: [dynamic]m.Vec3
	defer delete(pv)
	defer delete(pvt)
	defer delete(pvn)

	mh: Mesh
	seen: map[[3]int]u32 // (v,vt,vn) triple -> output vertex index
	defer delete(seen)
	had_normals := false

	it := src
	for line in strings.split_lines_iterator(&it) {
		l := strings.trim_space(line)
		if len(l) == 0 || l[0] == '#' {
			continue
		}

		if strings.has_prefix(l, "v ") {
			toks := strings.fields(l[2:]); defer delete(toks)
			if len(toks) >= 3 {
				append(&pv, m.Vec3{pf(toks[0]), pf(toks[1]), pf(toks[2])})
			}
		} else if strings.has_prefix(l, "vt ") {
			toks := strings.fields(l[3:]); defer delete(toks)
			if len(toks) >= 2 {
				append(&pvt, m.Vec2{pf(toks[0]), pf(toks[1])})
			}
		} else if strings.has_prefix(l, "vn ") {
			toks := strings.fields(l[3:]); defer delete(toks)
			if len(toks) >= 3 {
				append(&pvn, m.Vec3{pf(toks[0]), pf(toks[1]), pf(toks[2])})
				had_normals = true
			}
		} else if strings.has_prefix(l, "f ") {
			toks := strings.fields(l[2:]); defer delete(toks)
			face: [dynamic]u32; defer delete(face)

			for tok in toks {
				parts := strings.split(tok, "/"); defer delete(parts)
				vi := pint(parts[0])
				ti := (len(parts) > 1 && parts[1] != "") ? pint(parts[1]) : 0
				ni := (len(parts) > 2 && parts[2] != "") ? pint(parts[2]) : 0

				key := [3]int{vi, ti, ni}
				out, found := seen[key]
				if !found {
					pi  := obj_resolve(vi, len(pv))
					uii := obj_resolve(ti, len(pvt))
					nii := obj_resolve(ni, len(pvn))
					out = u32(len(mh.positions))
					append(&mh.positions, pi  >= 0 ? pv[pi]   : m.Vec3{})
					append(&mh.uvs,       uii >= 0 ? pvt[uii] : m.Vec2{})
					append(&mh.normals,   nii >= 0 ? pvn[nii] : m.Vec3{})
					seen[key] = out
				}
				append(&face, out)
			}

			// fan-triangulate: (0,1,2), (0,2,3), ...
			for i in 1 ..< len(face) - 1 {
				append(&mh.indices, face[0], face[i], face[i + 1])
			}
		}
	}

	if !had_normals {
		compute_normals(&mh)
	}
	return mh
}
