# Step 01 — Math foundations

> Part of the **GamePBR** devlog. Language: Odin · Target: CPU renderer → WebGPU.

**Status:** done — `make test` green (7/7).
**Goal:** Set up the vector/matrix/color types and helpers the whole renderer leans on.

## What & why
A renderer is mostly linear algebra. Positions, normals, directions, and colors are `Vec3`; transforms are `Mat4`. Before rasterizing anything, I want a small, trustworthy math layer so every later step can assume `dot`, `cross`, `normalize`, and the transform constructors just work.

The design choice: **lean on Odin's built-ins, hand-write only what carries meaning.** Odin's `[N]f32` arrays already give component-wise `+ - * /`, scalar broadcast (`v * 2`), and swizzling (`v.xyz`, `v.x`). Its `matrix` type already does `A * B` (matrix multiply) and `M * v` (matrix × column vector). So there's no reason to write a `Vec3.add` — that's noise. What's *worth* writing by hand is the stuff with geometric content: the cross product, normalization, reflection, and the transform matrices themselves.

## Theory: matrix conventions (the part everyone trips on)

"Convention" here bundles **two completely independent ideas** that both, confusingly, use the words *row* and *column*. Separate them and it's easy.

### Axis 1 — math convention: are points rows or columns?
This is how you *write* a transform. Two camps, and they are transposes of each other:

| | Column-vector | Row-vector |
|---|---|---|
| Used by | OpenGL, GLSL, Godot, most math texts | classic DirectX, some older CG books |
| Apply | `p' = M * p` (matrix on the left) | `p' = p * M` (matrix on the right) |
| Compose | right-to-left: `T * R * S` scales first | left-to-right: `S * R * T` scales first |
| Translation lives in | the **last column** | the **last row** |

Same transform, mirror-image matrix. That's the whole "there are different conventions" story — really just these two.

### Axis 2 — storage convention: what order are the 16 floats in memory?
Totally separate. *Row-major* stores each row contiguously (natural for C arrays); *column-major* stores each column contiguously (Fortran, OpenGL, GPUs). This is invisible to your math — it only matters when you hand raw bytes to another system.

### Why more than one convention exists
History, not reason. Math texts and OpenGL grew up column-vector; Microsoft's DirectX went row-vector; C stores arrays row-major while GPU APIs standardized on column-major. Nobody coordinated. So the classic bug is copying a matrix from a tutorial that used the *other* convention and getting everything transposed — rotations mirrored, translations in the wrong slot. Mixing conventions is the one thing to never do.

### What GamePBR picks (and why it's low-effort)
- **Math: column-vector.** `p' = M * p`, compose right-to-left, translation in the last column. Matches Godot / GLSL / WebGPU, so it'll feel familiar and port with no surprises.
- **Storage: don't think about it.** Odin stores column-major internally — exactly what WebGPU wants later, so no transpose when we get there. When you write a matrix *literal* you type it top-row-first (the readable way) and Odin quietly stores it column-major. That's all the doc means by "row-major literal, column-major storage" — a convenience, not a third thing to track.

So the entire mental burden is two rules: (1) when copying a formula from a reference, check if it's row- or column-vector; (2) for storage, nothing — Odin already matches the GPU.

**Tiny worked example** — translate then rotate a point, column-vector style:

```odin
M := mat4_translate({0, 5, 0}) * mat4_rotate({0, 1, 0}, math.PI / 2) // rotate first, then translate
p := mat4_mul_point(M, {1, 0, 0})   // rotate (1,0,0) about Y by 90°, then lift +5 in Y
// result ≈ (0, 5, -1)
```

Read the compose order right-to-left: the rotation (nearest the point) happens first, the translation second — which is what "compose right-to-left" means in practice.

### One more: points vs directions (the w coordinate)
A `Vec3` promoted to `Vec4` with `w = 1` is a position — translation affects it. With `w = 0` it's a direction — translation is ignored, which is what you want for normals and light vectors. That single bit is why `mat4_mul_point` and `mat4_mul_dir` are different procedures. And **normalize matters** because nearly all shading is dot products of *unit* vectors (`N·L`, `N·V`, `N·H`); if a vector drifts off unit length, lighting silently gets brighter or dimmer.

## Implementation
The math lives in its own package so it stays clean and reusable; the color bridge stays in `main` because it depends on the framebuffer's `Color`:

```
src/math/           package gmath  (named gmath, not "math" — Odin package
  vec.odin            names must be globally unique and core:math owns "math")
  mat.odin
  math_test.odin
src/math_color.odin  package main   (imports the math package as `m`)
```

- **`src/math/vec.odin`** — `Vec2/3/4`; `dot`, `cross`, `length`, `length_squared`, `normalize`, `lerp`, `reflect`, `saturate`.
- **`src/math/mat.odin`** — `Mat4`; `mat4_identity/translate/scale/rotate`, plus `mat4_mul_point` (w=1) and `mat4_mul_dir` (w=0).
- **`src/math/math_test.odin`** — invariants run by `make test`.
- **`src/math_color.odin`** — `color_to_vec3` / `vec3_to_color`, using `m.Vec3` and `m.saturate`.

Import it with an alias so it reads cleanly and never clashes with `core:math`:

```odin
import m "math"    // directory is src/math; package inside is `gmath`
// ... m.Vec3, m.dot(a, b), m.normalize(v)
```

The rotation constructor, written row-major so it matches any reference:

```odin
mat4_rotate :: proc(axis: Vec3, angle_rad: f32) -> Mat4 {
	a := normalize(axis)
	c := math.cos(angle_rad); s := math.sin(angle_rad); t := 1 - c
	x, y, z := a.x, a.y, a.z
	return Mat4{
		t*x*x + c,   t*x*y - s*z, t*x*z + s*y, 0,
		t*x*y + s*z, t*y*y + c,   t*y*z - s*x, 0,
		t*x*z - s*y, t*y*z + s*x, t*z*z + c,   0,
		0,           0,           0,           1,
	}
}
```

Deliberately *not* here: `perspective` and `look_at`. Those are camera concerns and get built (and explained) in step 05, so this package stays purely about primitives.

## Results
```
$ make test
Finished 7 tests in <1ms. All tests were successful.
```

The tests are small on purpose — a right-handed `cross`, `normalize` producing unit length, translation moving a point but not a direction. They're the tripwires that catch a sign flip before it becomes a "why is my model inside-out" mystery three steps later.

## Gotchas
- **Odin package names must be globally unique.** Naming the package `math` collides with `core:math` ("Duplicate declaration of 'package math'"). The directory can be `math`, but the package is `gmath`. Directory name and package name are unrelated in Odin.
- **Odin errors on unused imports and unused variables** — hard errors, not warnings. Keep imports tight.
- **Matrix literal order.** Row-major in source, column-major in storage. Write it like the paper math and trust Odin.
- **Color packing is linear for now.** `vec3_to_color` is a naive 0..1 → 0..255 map with truncation. Correct sRGB/gamma is its own milestone (step 14).
- **`normalize` guards the zero vector** — returns it unchanged instead of dividing by zero.

## References
- Odin overview (arrays, swizzling, matrices, packages): https://odin-lang.org/docs/overview/
- `core:math/linalg` (for `inverse`, etc. later): https://pkg.odin-lang.org/core/math/linalg/

## Next
→ **Step 02 — Framebuffer & image output**
