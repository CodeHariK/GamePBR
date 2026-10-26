package render

import "core:math"
import m "../math"

// --- Prefiltered environment: the split sum's first factor (step 16) ---
//
// For each roughness, store the environment convolved with the GGX lobe, so
// shading can read "the sky as a surface this rough would reflect it" with one
// lookup along the reflection vector R. Karis's simplification: assume the view
// looks straight down the normal (N = V = R) while prefiltering — the lobe then
// depends only on R and roughness, which is what lets it be tabulated. The cost
// is that grazing reflections don't stretch the way real ones do.

PREFILTER_LEVELS :: 5 // roughness 0, 0.25, 0.5, 0.75, 1

// Successive box-downsampled copies: [0] = full res, each next one half size.
// Used as a source "mip chain": a wide, sparse sample reads a blurrier copy.
env_mip_chain :: proc(env: ^EnvMap, count: int) -> [dynamic]EnvMap {
	chain: [dynamic]EnvMap
	base := env_create(env.width, env.height)
	copy(base.px, env.px)
	append(&chain, base)
	for len(chain) < count && chain[len(chain) - 1].width >= 4 {
		append(&chain, env_downsample(&chain[len(chain) - 1], 2))
	}
	return chain
}

env_mip_chain_destroy :: proc(chain: ^[dynamic]EnvMap) {
	for &e in chain { env_destroy(&e) }
	delete(chain^)
}

// Sample the chain at a fractional mip level (linear between the two nearest).
sample_mip_chain :: proc(chain: []EnvMap, d: m.Vec3, mip: f32) -> m.Vec3 {
	top := f32(len(chain) - 1)
	lv := clamp(mip, 0, top)
	l0 := int(lv)
	l1 := min(l0 + 1, len(chain) - 1)
	t := lv - f32(l0)
	return m.lerp(env_sample(&chain[l0], d), env_sample(&chain[l1], d), t)
}

// One prefiltered level: for every output direction R, average the environment
// over GGX-distributed reflection directions, weighted by n·l.
//
// Filtered importance sampling (Křivánek & Colbert): each sample stands in for
// a patch of the sphere of solid angle ≈ 1/(N·pdf). Reading the source at the
// mip whose texels are that big blurs the sample over its patch — so a few
// hundred samples give a smooth result even with a 300× sun in the sky.
prefilter_level :: proc(chain: []EnvMap, roughness: f32, w, h, samples: int) -> EnvMap {
	out := env_create(w, h)
	sa_texel := 4 * math.PI / f32(chain[0].width * chain[0].height)
	for y in 0 ..< h {
		for x in 0 ..< w {
			R := env_texel_dir(&out, x, y)
			N := R; V := R
			acc := m.Vec3{}
			weight: f32 = 0
			for i in 0 ..< samples {
				H := importance_sample_ggx(hammersley(i, samples), N, roughness)
				L := H * (2 * m.dot(V, H)) - V
				nl := m.dot(N, L)
				if nl <= 0 { continue }
				nh := m.saturate(m.dot(N, H))
				pdf := distribution_ggx(nh, roughness) / 4 + 1e-4 // = D·(n·h)/(4 v·h), with v·h = n·h
				sa_sample := 1 / (f32(samples) * pdf)
				mip := 0.5 * math.log2(sa_sample / sa_texel) + 1 // +1: a little extra blur kills fireflies
				acc += sample_mip_chain(chain, L, mip) * nl
				weight += nl
			}
			out.px[y * w + x] = weight > 0 ? acc / weight : m.Vec3{}
		}
	}
	return out
}

// All levels. Level 0 (roughness 0, a perfect mirror) is the environment
// itself; each rougher level is half the previous resolution — blurrier
// content needs fewer texels.
prefilter_env :: proc(env: ^EnvMap, samples: int) -> [PREFILTER_LEVELS]EnvMap {
	chain := env_mip_chain(env, 8)
	defer env_mip_chain_destroy(&chain)
	levels: [PREFILTER_LEVELS]EnvMap
	levels[0] = env_create(env.width, env.height)
	copy(levels[0].px, env.px)
	w := env.width; h := env.height
	for i in 1 ..< PREFILTER_LEVELS {
		w = max(w / 2, 8); h = max(h / 2, 4)
		r := f32(i) / f32(PREFILTER_LEVELS - 1)
		levels[i] = prefilter_level(chain[:], r, w, h, samples)
	}
	return levels
}

// Read the prefiltered environment for direction R at any roughness, blending
// between the two nearest levels.
sample_prefiltered :: proc(levels: ^[PREFILTER_LEVELS]EnvMap, R: m.Vec3, roughness: f32) -> m.Vec3 {
	lv := m.saturate(roughness) * f32(PREFILTER_LEVELS - 1)
	l0 := int(lv)
	l1 := min(l0 + 1, PREFILTER_LEVELS - 1)
	t := lv - f32(l0)
	return m.lerp(env_sample(&levels[l0], R), env_sample(&levels[l1], R), t)
}
