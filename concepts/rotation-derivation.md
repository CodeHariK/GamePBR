# Rotation: conventions, axis-angle, and turning a formula into a matrix

> Companion notes for [Step 01 — Math foundations](../docs/01-math.md). Deep-dive on the
> `mat4_rotate` constructor: which conventions we picked and why, why rotations
> are specified as axis-angle, and exactly how Rodrigues' vector formula becomes
> the 3×3 matrix in the code.

---

## 1. Matrix conventions (the part everyone trips on)

"Convention" bundles **two completely independent ideas** that both, confusingly,
use the words *row* and *column*. Separate them and it's easy.

### Axis 1 — math convention: are points rows or columns?

How you *write* a transform. Two camps, and they are transposes of each other:

| | Column-vector | Row-vector |
|---|---|---|
| Used by | OpenGL, GLSL, Godot, most math texts | classic DirectX, some older CG books |
| Apply | `p' = M * p` (matrix on the left) | `p' = p * M` (matrix on the right) |
| Compose | right-to-left: `T * R * S` scales first | left-to-right: `S * R * T` scales first |
| Translation lives in | the **last column** | the **last row** |

Same transform, mirror-image matrix. That's the whole "different conventions"
story — really just these two.

### Axis 2 — storage convention: what order are the 16 floats in memory?

Totally separate. *Row-major* stores each row contiguously (natural for C arrays);
*column-major* stores each column contiguously (Fortran, OpenGL, GPUs). Invisible
to your math — it only matters when you hand raw bytes to another system.

### Why more than one convention exists

History, not reason. Math texts and OpenGL grew up column-vector; Microsoft's
DirectX went row-vector; C stores arrays row-major while GPU APIs standardized on
column-major. Nobody coordinated. So the classic bug is copying a matrix from a
tutorial that used the *other* convention and getting everything transposed.
**Mixing conventions is the one thing to never do.**

### What GamePBR picks (and why it's low-effort)

- **Math: column-vector.** `p' = M * p`, compose right-to-left, translation in the
  last column. Matches Godot / GLSL / WebGPU — familiar, and ports with no surprises.
- **Storage: don't think about it.** Odin stores column-major internally (what
  WebGPU wants later, so no transpose). You *write* a matrix literal top-row-first
  (readable) and Odin stores it column-major. That's all "row-major literal,
  column-major storage" means — a convenience, not a third thing to track.

Entire mental burden: (1) when copying a formula, check if it's row- or
column-vector; (2) for storage, nothing — Odin already matches the GPU.

---

## 2. Why axis-angle instead of a "rotation matrix"

`mat4_rotate` **is** a rotation matrix — axis-angle is the *input* we use to *build*
it, not an alternative to it. Ways to specify a rotation:

- **Euler angles** — three angles (yaw/pitch/roll), built as `Rz * Ry * Rx`.
  Intuitive to type, but order-dependent and suffers **gimbal lock** (two axes can
  align and you lose a degree of freedom).
- **Axis-angle (what we use)** — "rotate by θ around this one unit axis `k`." One
  general formula, no gimbal lock for a single rotation, minimal parameters.
- **Quaternions** — best when you *accumulate* or *interpolate* rotations
  (animation, cameras); compact and drift-free. Still converted to a matrix to feed
  the pipeline.
- **A raw rotation matrix** — you almost never hand-author 9 numbers; you generate
  them from one of the above.

**Why axis-angle for the constructor:** it's the most *general single-rotation
primitive*. The three cardinal-axis rotations are just special cases — plug in
`k = (1,0,0)` and you get the standard `Rx`; `(0,1,0)` → `Ry`; `(0,0,1)` → `Rz`. So
one small function replaces three near-duplicate ones, and it also handles the
arbitrary-axis cases you actually want later (rotate a model about its own up
vector, arcball camera). Its one weakness — accumulating many rotations over time —
is exactly what quaternions fix, so we'd add those later if animation needs them.

---

## 3. Turning Rodrigues' formula into a matrix

**Rodrigues' rotation formula** — the *vector* statement of rotating `v` around unit
axis `k` by angle θ:

```
v' = v·cosθ  +  (k × v)·sinθ  +  k·(k·v)·(1 − cosθ)
```

The trick to get a matrix: **any expression that's linear in `v` can be rewritten as
(some matrix) × v** — you read the matrix off by collecting the coefficients of each
component of `v`. We apply that trick to all three terms, then add the matrices.

Let `k = (x, y, z)` (the axis) and `v = (a, b, c)` (the vector being rotated).

### Term 1 — `v·cosθ`  →  `c·I`

Scaling `v` by the number `cosθ` is just the identity matrix times `cosθ`:

```
c·I = [ c 0 0 ]
      [ 0 c 0 ]
      [ 0 0 c ]
```

### Term 2 — `(k × v)·sinθ`  →  `s·K`

Write out `k × v` component by component (cross-product definition):

```
k × v = ( y·c − z·b ,   z·a − x·c ,   x·b − y·a )
```

Now rewrite each output as "coeff·a + coeff·b + coeff·c":

```
1st:  y·c − z·b  =   0·a  + (−z)·b + ( y)·c
2nd:  z·a − x·c  =  ( z)·a +  0·b  + (−x)·c
3rd:  x·b − y·a  =  (−y)·a + ( x)·b +  0·c
```

The grid of coefficients on the right **is** the matrix:

```
K = [  0   −z    y ]
    [  z    0   −x ]
    [ −y    x    0 ]
```

By construction `K · v = k × v` for any `v`. So "cross with k" and "multiply by K"
are the same operation; K is that operation frozen into a matrix. The signs mirrored
across the diagonal are why it's called **skew-symmetric** (flip across the diagonal
→ negate).

### Term 3 — `k·(k·v)·(1 − cosθ)`  →  `t·(k·kᵀ)`

Read the term inside-out:

- `k·v` is the **dot product**, a single number: `k·v = x·a + y·b + z·c`.
- `k·(that number)` scales the vector `k` by it:
  `( x·(k·v), y·(k·v), z·(k·v) )`.

Same trick — express each output as coefficients of `a, b, c`. Take the first:

```
x·(k·v) = x·(x·a + y·b + z·c) = (x·x)·a + (x·y)·b + (x·z)·c
```

Do all three and stack the coefficient rows:

```
k·kᵀ = [ x·x   x·y   x·z ]
       [ y·x   y·y   y·z ]
       [ z·x   z·y   z·z ]
```

The name `k·kᵀ` ("outer product") is shorthand: a column vector `k` times a row
vector `kᵀ` makes a 3×3 grid where entry (i,j) = kᵢ·kⱼ. And `(k·kᵀ)·v = k·(k·v)` —
same thing, matrix form.

### Adding the three matrices

All three terms are now "(matrix) × the *same* v", so multiply once:

```
v' = c·I·v + s·K·v + t·(k·kᵀ)·v = ( c·I + s·K + t·k·kᵀ )·v
```

(You couldn't add them while they were still "cross product" and "dot product"
expressions — turning each into a matrix is exactly what lets you combine them.)

With `c = cosθ`, `s = sinθ`, `t = 1 − cosθ`, adding the grids entry-by-entry:

```
      [ t·x² + c     t·xy − s·z   t·xz + s·y ]
R  =  [ t·xy + s·z   t·y² + c     t·yz − s·x ]
      [ t·xz − s·y   t·yz + s·x   t·z² + c   ]
```

which is exactly the code in `src/math/mat.odin`:

```odin
t*x*x + c,   t*x*y - s*z, t*x*z + s*y,
t*x*y + s*z, t*y*y + c,   t*y*z - s*x,
t*x*z - s*y, t*y*z + s*x, t*z*z + c,
```

- diagonal: the `+ c` comes from `c·I`; the `t·(square)` from `k·kᵀ`.
- off-diagonal: the symmetric `t·(product)` from `k·kᵀ`; the antisymmetric `± s·(component)`
  from `K` — which is why swapping across the diagonal flips the `s` sign.

---

## 4. Worked example: `k = (0, 0, 1)` collapses to Rz

Set `x = 0, y = 0, z = 1`. Grind terms 2 and 3:

**K** (put `x=y=0, z=1` into the K grid):

```
K = [  0  −1   0 ]
    [  1   0   0 ]
    [  0   0   0 ]
```

**k·kᵀ** (only `z·z = 1` is non-zero):

```
k·kᵀ = [ 0  0  0 ]
       [ 0  0  0 ]
       [ 0  0  1 ]
```

Now `R = c·I + s·K + t·(k·kᵀ)`:

```
c·I           s·K              t·(k·kᵀ)          sum = R
[c 0 0]   +   [0 −s 0]    +    [0 0 0]     =    [ c  −s  0 ]
[0 c 0]       [s  0 0]         [0 0 0]          [ s   c  0 ]
[0 0 c]       [0  0 0]         [0 0 t]          [ 0   0  c+t ]
```

and `c + t = cosθ + (1 − cosθ) = 1`, so the bottom-right is `1`:

```
Rz = [ c  −s  0 ]
     [ s   c  0 ]
     [ 0   0  1 ]
```

The textbook z-axis rotation. Watching the pieces cancel — the `t` term filling only
the z-diagonal, `K` supplying the `±s` off-diagonal spin in the x-y plane — is the
"aha" for how the general formula contains all the simple ones.

## See also
- [Step 01 — Math foundations](../docs/01-math.md) — the code these notes explain.
