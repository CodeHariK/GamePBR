package render

import "core:math"
import m "../math"

// --- Environment maps (step 15) ---
//
// An environment map stores the radiance arriving from EVERY direction — the
// whole sky as one image. We use the equirectangular (lat-long) layout: u is
// longitude (0..1 around), v is latitude from straight up (0) to straight down
// (1). Texels hold LINEAR HDR radiance (the sun can be hundreds of times
// brighter than the sky), so it's []Vec3, not 8-bit color.

EnvMap :: struct {
	width:  int,
	height: int,
	px:     []m.Vec3,
}

env_create :: proc(w, h: int) -> EnvMap {
	return EnvMap{width = w, height = h, px = make([]m.Vec3, w * h)}
}

env_destroy :: proc(e: ^EnvMap) {
	delete(e.px)
	e^ = {}
}

// Direction -> (u, v). −Z (the camera's default forward) maps to the centre.
dir_to_equirect :: proc(d: m.Vec3) -> (u, v: f32) {
	u = 0.5 + math.atan2(d.x, -d.z) / (2 * math.PI)
	v = math.acos(clamp(d.y, -1, 1)) / math.PI
	return
}

// (u, v) -> unit direction. θ = polar angle from +Y, φ = longitude.
equirect_to_dir :: proc(u, v: f32) -> m.Vec3 {
	theta := v * math.PI
	phi := (u - 0.5) * 2 * math.PI
	st := math.sin(theta)
	return m.Vec3{st * math.sin(phi), math.cos(theta), -st * math.cos(phi)}
}

// Centre direction of texel (x, y).
env_texel_dir :: proc(e: ^EnvMap, x, y: int) -> m.Vec3 {
	return equirect_to_dir((f32(x) + 0.5) / f32(e.width), (f32(y) + 0.5) / f32(e.height))
}

// Solid angle (steradians) covered by one texel in row y. Rows near the poles
// are squeezed: dω = dφ · dθ · sinθ. All texels together sum to 4π.
env_texel_solid_angle :: proc(e: ^EnvMap, y: int) -> f32 {
	theta := (f32(y) + 0.5) / f32(e.height) * math.PI
	return (2 * math.PI / f32(e.width)) * (math.PI / f32(e.height)) * math.sin(theta)
}

// Bilinear sample at (u, v): u wraps (longitude is circular), v clamps.
env_sample_uv :: proc(e: ^EnvMap, u, v: f32) -> m.Vec3 {
	fx := u * f32(e.width) - 0.5
	fy := clamp(v * f32(e.height) - 0.5, 0, f32(e.height - 1))
	x0 := int(math.floor(fx)); y0 := int(fy)
	tx := fx - f32(x0); ty := fy - f32(y0)
	y1 := min(y0 + 1, e.height - 1)
	wrap :: proc(x, w: int) -> int { return ((x % w) + w) % w }
	xa := wrap(x0, e.width); xb := wrap(x0 + 1, e.width)
	top := m.lerp(e.px[y0 * e.width + xa], e.px[y0 * e.width + xb], tx)
	bot := m.lerp(e.px[y1 * e.width + xa], e.px[y1 * e.width + xb], tx)
	return m.lerp(top, bot, ty)
}

env_sample :: proc(e: ^EnvMap, d: m.Vec3) -> m.Vec3 {
	u, v := dir_to_equirect(d)
	return env_sample_uv(e, u, v)
}

// Box-filter by an integer factor. Averaging preserves the mean radiance, so
// the lighting a downsampled map delivers is (nearly) unchanged — it only
// loses detail the irradiance convolution would blur away anyway.
env_downsample :: proc(src: ^EnvMap, k: int) -> EnvMap {
	out := env_create(src.width / k, src.height / k)
	inv := 1.0 / f32(k * k)
	for y in 0 ..< out.height {
		for x in 0 ..< out.width {
			acc := m.Vec3{}
			for j in 0 ..< k {
				for i in 0 ..< k {
					acc += src.px[(y * k + j) * src.width + (x * k + i)]
				}
			}
			out.px[y * out.width + x] = acc * inv
		}
	}
	return out
}

// Irradiance convolution: for every normal direction N (one output texel),
//     E(N) = ∫_Ω L(ω) · max(N·ω, 0) dω
// computed as a Riemann sum over every source texel weighted by its solid angle.
// E is what a perfectly diffuse surface facing N receives from the whole sky.
// Brute force — O(out × src) — but it runs once, offline, on a small map.
convolve_irradiance :: proc(src: ^EnvMap, out_w, out_h: int) -> EnvMap {
	n := src.width * src.height
	dirs := make([]m.Vec3, n)
	weighted := make([]m.Vec3, n) // L · dω, precomputed once
	defer delete(dirs)
	defer delete(weighted)
	for y in 0 ..< src.height {
		dw := env_texel_solid_angle(src, y)
		for x in 0 ..< src.width {
			i := y * src.width + x
			dirs[i] = env_texel_dir(src, x, y)
			weighted[i] = src.px[i] * dw
		}
	}
	out := env_create(out_w, out_h)
	for y in 0 ..< out_h {
		for x in 0 ..< out_w {
			N := env_texel_dir(&out, x, y)
			E := m.Vec3{}
			for i in 0 ..< n {
				c := m.dot(N, dirs[i])
				if c > 0 { E += weighted[i] * c }
			}
			out.px[y * out_w + x] = E
		}
	}
	return out
}

// --- A procedural HDR sky: no asset files, fully deterministic. ---

SKY_ZENITH   :: m.Vec3{0.18, 0.36, 0.85}
SKY_HORIZON  :: m.Vec3{0.85, 0.90, 1.00}
SKY_GROUND   :: m.Vec3{0.20, 0.15, 0.10}
SUN_COLOR    :: m.Vec3{1.00, 0.92, 0.80}
SUN_RADIANCE :: f32(300)   // disk radiance: ~300× the sky
SUN_RADIUS   :: f32(0.045) // angular radius, radians (~2.5°)
SUN_HALO     :: f32(3)     // soft glow around the disk

make_sky_env :: proc(w, h: int, sun_dir: m.Vec3) -> EnvMap {
	e := env_create(w, h)
	sun := m.normalize(sun_dir)
	cos_sun := math.cos(SUN_RADIUS)
	for y in 0 ..< h {
		for x in 0 ..< w {
			d := env_texel_dir(&e, x, y)
			col: m.Vec3
			if d.y >= 0 {
				col = m.lerp(SKY_HORIZON, SKY_ZENITH, math.sqrt(d.y))
			} else {
				// darken the horizon colour into the ground over a thin band
				col = m.lerp(SKY_HORIZON * 0.5, SKY_GROUND, m.saturate(-d.y / 0.08))
			}
			cd := m.dot(d, sun)
			if cd > cos_sun { col += SUN_COLOR * SUN_RADIANCE }
			col += SUN_COLOR * (SUN_HALO * math.pow(max(cd, 0), 64))
			e.px[y * w + x] = col
		}
	}
	return e
}
