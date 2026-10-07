// Whole map in ONE fragment shader: orthographic globe or flat equirect, province borders,
// lens colours (via palette texture), selection/hover rings, relation patterns (war hatch, ally double line, own heavy line), atmosphere.
// Province IDs live in an RG8 texture (u16 little endian); colours/owners in a 4-row palette.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ids : filter_nearest, repeat_disable;
uniform sampler2D pal : filter_nearest, repeat_disable;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 id_size = vec2(2048.0, 1024.0);
uniform float lon0 = 0.0;
uniform float lat0 = 0.3;
uniform float radius = 300.0;
uniform float flat_scale = 200.0;
uniform int mode = 0;            // 0 globe, 1 flat
uniform int sel_id = -1;         // province id (index+1) or -1
uniform int hover_id = -1;
uniform float sel_t = 1.0;        // 0..1 fade-in of the selection
uniform float hover_t = 0.0;      // 0..1 fade of the hover highlight
uniform int hover_prev = -1;      // province whose hover highlight is fading out
uniform float hover_prev_t = 0.0;
uniform int theme = 0;           // 0 standard, 1 parchment
uniform int hc = 0;              // 1 = high-contrast map: 2x borders, lifted land, black sea, no rim light
uniform int strong = 0;          // 1 = colour-vision / high-contrast: relation patterns at full strength
uniform float px_scale = 1.0;    // render resolution / logical resolution (patterns and strokes are in logical px)
uniform int hi_owner = -1;       // nation lit on the pick screen (others dim), -1 none
uniform int quality = 2;         // 0 low (no province borders), 1 medium, 2 high
uniform float dim_others = 0.0;   // 1 while orders are armed: land that is not a target (or the selection) recedes
uniform vec4 bg_color : source_color = vec4(0.024, 0.039, 0.078, 1.0);


// pixel -> lon/lat (radians). n = view-space normal on the globe (z toward viewer). false if off-map.
bool unproject(vec2 p, out float lon, out float lat, out vec3 n) {
	if (mode == 0) {
		vec2 d = (p - rect_size * 0.5) / radius;
		d.y = -d.y;
		float r2 = dot(d, d);
		if (r2 >= 1.0) return false;
		float z = sqrt(1.0 - r2);
		float s0 = sin(lat0), c0 = cos(lat0);
		lat = asin(clamp(z * s0 + d.y * c0, -1.0, 1.0));
		lon = lon0 + atan(d.x, z * c0 - d.y * s0);
		n = vec3(d, z);
		return true;
	}
	lon = lon0 + (p.x - rect_size.x * 0.5) / flat_scale;
	lat = lat0 - (p.y - rect_size.y * 0.5) / flat_scale;
	n = vec3(0.0, 0.0, 1.0);
	return abs(lat) <= PI * 0.5;
}

vec2 tex_coord(float lon, float lat) {
	float u = lon / TAU + 0.5;
	u = u - floor(u);
	return vec2(u * id_size.x, (0.5 - lat / PI) * id_size.y);
}

int id_at(ivec2 t) {
	int w = int(id_size.x);
	t.x = ((t.x % w) + w) % w;
	t.y = clamp(t.y, 0, int(id_size.y) - 1);
	vec4 c = texelFetch(ids, t, 0);
	return int(c.r * 255.0 + 0.5) + int(c.g * 255.0 + 0.5) * 256;
}


// Bilinear-threshold smoothed province id: removes the texel staircase at high zoom.
// Ocean (id 0) is down-weighted so tiny islands do not vanish.
int smooth_id(vec2 t) {
	vec2 tt = t - 0.5;
	ivec2 b = ivec2(floor(tt));
	vec2 fr = tt - floor(tt);
	int i0 = id_at(b);
	int i1 = id_at(b + ivec2(1, 0));
	int i2 = id_at(b + ivec2(0, 1));
	int i3 = id_at(b + ivec2(1, 1));
	float w0 = (1.0 - fr.x) * (1.0 - fr.y);
	float w1 = fr.x * (1.0 - fr.y);
	float w2 = (1.0 - fr.x) * fr.y;
	float w3 = fr.x * fr.y;
	float s0 = w0 + (i1 == i0 ? w1 : 0.0) + (i2 == i0 ? w2 : 0.0) + (i3 == i0 ? w3 : 0.0);
	float s1 = (i1 == i0) ? 0.0 : w1 + (i2 == i1 ? w2 : 0.0) + (i3 == i1 ? w3 : 0.0);
	float s2 = (i2 == i0 || i2 == i1) ? 0.0 : w2 + (i3 == i2 ? w3 : 0.0);
	float s3 = (i3 == i0 || i3 == i1 || i3 == i2) ? 0.0 : w3;
	if (i0 == 0) s0 *= 0.7;
	if (i1 == 0) s1 *= 0.7;
	if (i2 == 0) s2 *= 0.7;
	if (i3 == 0) s3 *= 0.7;
	int best = i0; float bw = s0;
	if (s1 > bw) { best = i1; bw = s1; }
	if (s2 > bw) { best = i2; bw = s2; }
	if (s3 > bw) { best = i3; }
	return best;
}

// ---- close-zoom quality: when a texel covers several pixels the bilinear-threshold edge turns into visible diamonds.
// Here every candidate id gets a quadratic B-spline weight over a 3x3 neighbourhood and the heaviest wins: the borders
// become smooth curves. A little low-frequency domain warp then breaks the remaining straight runs (hand-drawn look).
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
int hq_id(vec2 t) {
	vec2 w2 = vec2(vnoise(t * 0.55), vnoise(t * 0.55 + vec2(17.3, 5.1))) - 0.5;
	vec2 tt = t + w2 * 0.9 - 0.5;                       // warp amplitude ~0.45 texel
	ivec2 b = ivec2(floor(tt + 0.5));
	vec2 f = tt - vec2(b);                               // -0.5 .. 0.5
	vec3 wx = vec3(0.5 * (0.5 - f.x) * (0.5 - f.x), 0.75 - f.x * f.x, 0.5 * (0.5 + f.x) * (0.5 + f.x));
	vec3 wy = vec3(0.5 * (0.5 - f.y) * (0.5 - f.y), 0.75 - f.y * f.y, 0.5 * (0.5 + f.y) * (0.5 + f.y));
	int cid[9];
	float cw[9];
	int n = 0;
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 3; i++) {
			int id = id_at(b + ivec2(i - 1, j - 1));
			float w = wx[i] * wy[j] * (id == 0 ? 0.72 : 1.0);   // ocean down-weighted so thin islands survive
			bool found = false;
			for (int k = 0; k < n; k++) {
				if (cid[k] == id) { cw[k] += w; found = true; }
			}
			if (!found) { cid[n] = id; cw[n] = w; n++; }
		}
	}
	int best = cid[0]; float bw = cw[0];
	for (int k = 1; k < n; k++) {
		if (cw[k] > bw) { bw = cw[k]; best = cid[k]; }
	}
	return best;
}

int owner_of(int id) {
	if (id == 0) return 0;
	vec4 c = texelFetch(pal, ivec2(id, 1), 0);
	return int(c.r * 255.0 + 0.5) + int(c.g * 255.0 + 0.5) * 256;
}
float flags_of(int id) {
	if (id == 0) return 0.0;
	return floor(texelFetch(pal, ivec2(id, 1), 0).b * 255.0 + 0.5);
}

vec2 wrap_dt(vec2 d) {
	if (d.x > id_size.x * 0.5) d.x -= id_size.x;
	if (d.x < -id_size.x * 0.5) d.x += id_size.x;
	return d;
}


// ---- screen-space strokes. All distances are in LOGICAL px (ex / ey = texel offset of one logical px along screen x / y).
const vec2 D8[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0), vec2(0.7071, 0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, 0.7071), vec2(-0.7071, -0.7071));

int sid(vec2 tt, bool hqf) {
	if (hqf) return hq_id(tt);
	if (quality >= 2) return smooth_id(tt);
	return id_at(ivec2(floor(tt)));
}

// distance (1..maxr px) from a pixel INSIDE province `target` to its border; 99 when farther
float edge_in(vec2 t, vec2 ex, vec2 ey, int target, bool hqf, int maxr) {
	for (int k = 1; k <= 5; k++) {
		if (k > maxr) break;
		float r = float(k);
		for (int i = 0; i < 8; i++) {
			if (sid(t + (ex * D8[i].x + ey * D8[i].y) * r, hqf) != target) return r;
		}
	}
	return 99.0;
}

// 1 = within `w` px inside the border of province `target`, 2 = within `wo` px outside it, 0 = elsewhere. A cheap nearest-texel probe rejects most pixels first.
float ring_of(vec2 t, vec2 ex, vec2 ey, int id, int target, bool hqf, float w, float wo) {
	float reach = max(w, wo) + 1.5;
	bool inside = id == target;
	bool near = false;
	for (int i = 0; i < 8; i++) {
		int c = id_at(ivec2(floor(t + (ex * D8[i].x + ey * D8[i].y) * reach)));
		if (inside) { if (c != target) near = true; }
		else if (c == target) near = true;
	}
	if (!near) return 0.0;
	if (inside) return edge_in(t, ex, ey, target, hqf, int(ceil(w))) <= w ? 1.0 : 0.0;
	for (int k = 1; k <= 3; k++) {
		if (float(k) > wo) break;
		for (int i = 0; i < 8; i++) {
			if (sid(t + (ex * D8[i].x + ey * D8[i].y) * float(k), hqf) == target) return 2.0;
		}
	}
	return 0.0;
}

// nearest border to another nation's LAND (the sea does not count): x = px distance (1..maxr, 99 none), y = that neighbour's relation class
vec2 nat_edge(vec2 t, vec2 ex, vec2 ey, int own, bool hqf, int maxr) {
	float reach = float(maxr) + 1.5;
	bool near = false;
	for (int i = 0; i < 8; i++) {
		int c = id_at(ivec2(floor(t + (ex * D8[i].x + ey * D8[i].y) * reach)));
		if (c != 0 && owner_of(c) != own) near = true;
	}
	if (!near) return vec2(99.0, 0.0);
	for (int k = 1; k <= 5; k++) {
		if (k > maxr) break;
		for (int i = 0; i < 8; i++) {
			int c = sid(t + (ex * D8[i].x + ey * D8[i].y) * float(k), hqf);
			if (c != 0 && owner_of(c) != own) return vec2(float(k), flags_of(c));
		}
	}
	return vec2(99.0, 0.0);
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 lp = p / px_scale;                              // logical px: pattern pitch and stroke widths
	float lon, lat;
	vec3 n;
	if (!unproject(p, lon, lat, n)) {
		vec3 c = bg_color.rgb;
		if (mode == 0 && hc == 0) {
			float r = length((p - rect_size * 0.5) / radius);
			float glow = smoothstep(1.14, 1.0, r);
			c += vec3(0.16, 0.27, 0.46) * glow * 0.5;
		}
		COLOR = vec4(c, 1.0);
	} else {
		vec2 t = tex_coord(lon, lat);
		ivec2 ti = ivec2(floor(t));
		vec2 f = t - floor(t);
		// texels per screen pixel (finite differences; robust at the lon seam)
		float lon1, lat1; vec3 n1;
		vec2 dtx = vec2(0.0), dty = vec2(0.0);
		if (unproject(p + vec2(1.0, 0.0), lon1, lat1, n1)) dtx = wrap_dt(tex_coord(lon1, lat1) - t);
		if (unproject(p + vec2(0.0, 1.0), lon1, lat1, n1)) dty = wrap_dt(tex_coord(lon1, lat1) - t);
		float tpp = max(max(length(dtx), length(dty)), 0.0001);
		bool hq = quality >= 2 && tpp < 0.5;                 // a texel spans two or more pixels
		int id = hq ? hq_id(t) : ((quality >= 2) ? smooth_id(t) : id_at(ti));
		vec2 ex = dtx * px_scale;                            // texel step of one logical px
		vec2 ey = dty * px_scale;

		vec3 col;
		int own = owner_of(id);
		float fl = flags_of(id);
		if (id == 0) {
			float lat_d = degrees(lat), lon_d = degrees(lon);
			col = mix(vec3(0.045, 0.11, 0.24), vec3(0.07, 0.17, 0.34), clamp(1.0 - abs(lat) / (PI * 0.5), 0.0, 1.0));
			if (theme == 1) col = mix(vec3(0.62, 0.70, 0.72), vec3(0.70, 0.76, 0.76), clamp(1.0 - abs(lat) / (PI * 0.5), 0.0, 1.0));
			if (hc == 1) col = vec3(0.0, 0.015, 0.04);
			// faint graticule every 15 degrees
			float gl = min(abs(fract(lat_d / 15.0 + 0.5) - 0.5) * 15.0, abs(fract(lon_d / 15.0 + 0.5) - 0.5) * 15.0 * cos(lat));
			col += vec3(0.05, 0.09, 0.16) * (1.0 - smoothstep(0.0, tpp * 0.18 + 0.01, gl)) * 0.6 * (hc == 1 ? 0.0 : 1.0);
		} else {
			col = texelFetch(pal, ivec2(id, 0), 0).rgb;
			if (hc == 1) col = 0.35 + 0.65 * col;               // land never darker than 3:1 against the black sea
			vec4 occ = texelFetch(pal, ivec2(id, 2), 0);
			if (occ.a > 0.5 && mod(p.x + p.y, 8.0) < 4.0) col = occ.rgb;
			bool is_tgt = texelFetch(pal, ivec2(id, 3), 0).r > 0.5;
			if (is_tgt) {
				col = mix(col, vec3(0.95, 0.77, 0.32), 0.12);   // valid target: 12 % brass tint (+ a 2 px outline below), static
				if (strong == 1 && mod(floor(lp.x / 4.0) + floor(lp.y / 4.0), 2.0) < 1.0) col = mix(col, vec3(0.95, 0.77, 0.32), 0.4);   // dotted fill: not hue alone
			}
			else if (dim_others > 0.5 && id != sel_id) col *= 0.6;
			if (hi_owner >= 0) col = (own == hi_owner) ? min(col * 1.12 + 0.03, vec3(1.0)) : col * 0.32;   // pick screen: the chosen nation lit, the rest at ~30 %
			if (id == sel_id) col = mix(col, min(col * 1.08 + 0.02, vec3(1.0)), sel_t);                // selection: +8 %, no wash, no pulse
		}

		if (theme == 1 && id != 0) col = mix(col, vec3(0.86, 0.76, 0.55) * (0.55 + 0.9 * dot(col, vec3(0.33))), 0.62);   // aged-paper wash
		// ---- borders (constant screen width) ----
		float e_nat = 1e4, e_prov = 1e4, e_coast = 1e4, e_war = 1e4, e_tgt = 1e4, e_hi = 1e4;
		float my_tgt = id == 0 ? 0.0 : texelFetch(pal, ivec2(id, 3), 0).r;
		float hcm = hc == 1 ? 2.0 : 1.0;
		if (quality >= 2 && id != 0 && hc == 0) {
			// inner rim light along national borders: probe a few pixels out in four directions
			float rim_w = 0.0;
			vec2 dirs[4] = vec2[4](dtx, -dtx, dty, -dty);
			for (int i = 0; i < 4; i++) {
				int n1i = id_at(ivec2(floor(t + dirs[i] * 2.5)));
				int n2i = id_at(ivec2(floor(t + dirs[i] * 5.0)));
				if (n1i != id && n1i != 0 && owner_of(n1i) != own) rim_w += 0.5;
				else if (n2i != id && n2i != 0 && owner_of(n2i) != own) rim_w += 0.22;
			}
			col = mix(col, col * 1.3 + vec3(0.045), clamp(rim_w, 0.0, 1.0) * 0.5);
		}
		// ---- relation patterns on the national borders (never hue alone): war = 45 degree hatch on the shared front, ally = double line,
		// own = heavy line, truce / NAP = dotted, rebels = cross-hatch. Subtle in the standard look, full strength when `strong`.
		if (id != 0 && own != 0 && quality >= 1 && (fl > 0.5 || strong == 1)) {
			bool band_hq = hq && quality >= 2;
			vec2 ne = nat_edge(t, ex, ey, own, band_hq, strong == 1 ? 5 : 3);
			float dn = ne.x; float nfl = ne.y;
			float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
			vec3 line_c = lum > 0.42 ? vec3(0.07, 0.05, 0.04) : vec3(0.95, 0.92, 0.82);
			if (dn < 90.0) {
				if ((fl == 1.0 && nfl == 2.0) || (fl == 2.0 && nfl == 1.0)) {
					float ph = mod(lp.x + lp.y, 6.0);
					if (ph < 2.0) col = mix(col, line_c, strong == 1 ? 0.95 : 0.7);
					else if (ph < 3.0 && strong == 1) col = mix(col, vec3(0.93, 0.25, 0.20), 0.8);
				} else if (fl == 1.0) {
					if (dn <= (strong == 1 ? 3.0 : 2.0)) col = mix(col, vec3(0.95, 0.77, 0.32), strong == 1 ? 0.95 : 0.8);
				} else if (fl == 3.0) {
					if (dn <= 1.0 || (dn >= 3.0 && dn <= 4.0)) col = mix(col, vec3(0.49, 0.70, 0.91), strong == 1 ? 0.95 : 0.7);
				} else if (fl == 4.0) {
					if (dn <= 2.0 && mod(floor(lp.x / 3.0) + floor(lp.y / 3.0), 2.0) < 1.0) col = mix(col, vec3(0.95, 0.92, 0.82), 0.8);
				}
				if (strong == 1 && dn >= 2.0 && dn <= 3.0 && fl != 1.0) col = mix(col, vec3(0.95, 0.92, 0.82), 0.45);   // light inner stroke
			}
		}
		if (fl == 5.0 && (mod(lp.x + lp.y, 6.0) < 1.0 || mod(lp.x - lp.y, 6.0) < 1.0)) col = mix(col, vec3(0.07, 0.05, 0.04), strong == 1 ? 0.55 : 0.3);
		if (quality >= 2) {
			// screen-space: compare smoothed ids one pixel to the right / below
			float lw = (1.0 + 1.3 * smoothstep(0.4, 0.04, tpp)) * hcm;          // line weight grows as you zoom in: 1 px far away, ~2.3 px close; 2x in high contrast
			vec2 ox = dtx * lw, oy = dty * lw;
			int nids[2] = hq ? int[2](hq_id(t + ox), hq_id(t + oy)) : int[2](smooth_id(t + ox), smooth_id(t + oy));
			for (int i = 0; i < 2; i++) {
				int nid = nids[i];
				if (nid == id) continue;
				float d = 0.0;
				if (my_tgt > 0.5 || (nid != 0 && texelFetch(pal, ivec2(nid, 3), 0).r > 0.5)) e_tgt = min(e_tgt, d);
				if (id == 0 || nid == 0) { e_coast = min(e_coast, d); continue; }
				int nown = owner_of(nid);
				if (nown != own) {
					e_nat = min(e_nat, d);
					if (hi_owner >= 0 && (own == hi_owner || nown == hi_owner)) e_hi = min(e_hi, d);
					float nfl = flags_of(nid);
					if ((fl >= 2.0 && fl < 3.0 && nfl == 1.0) || (nfl >= 2.0 && nfl < 3.0 && fl == 1.0)) e_war = min(e_war, d);
				} else {
					e_prov = min(e_prov, d);
				}
			}
		} else {
			ivec2 offs[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
			float dist[4] = float[4](1.0 - f.x, f.x, 1.0 - f.y, f.y);
			for (int i = 0; i < 4; i++) {
				int nid = id_at(ti + offs[i]);
				if (nid == id) continue;
				float d = dist[i] / tpp;
				if (my_tgt > 0.5 || (nid != 0 && texelFetch(pal, ivec2(nid, 3), 0).r > 0.5)) e_tgt = min(e_tgt, d);
				if (id == 0 || nid == 0) { e_coast = min(e_coast, d); continue; }
				int nown = owner_of(nid);
				if (nown != own) {
					e_nat = min(e_nat, d);
					if (hi_owner >= 0 && (own == hi_owner || nown == hi_owner)) e_hi = min(e_hi, d);
					float nfl = flags_of(nid);
					if ((fl >= 2.0 && fl < 3.0 && nfl == 1.0) || (nfl >= 2.0 && nfl < 3.0 && fl == 1.0)) e_war = min(e_war, d);
				} else if (quality > 0) {
					e_prov = min(e_prov, d);
				}
			}
		}
		float prov_alpha = clamp(2.2 - tpp, 0.0, 1.0) * (hc == 1 ? 0.7 : 0.45);
		col = mix(col, col * 0.55, clamp(0.5 + 0.8 - e_prov, 0.0, 1.0) * prov_alpha);
		vec3 nat_line = (theme == 1) ? vec3(0.30, 0.18, 0.08) : vec3(0.04, 0.05, 0.07);
		col = mix(col, nat_line, clamp(1.4 - e_nat + 0.5, 0.0, 1.0) * (hc == 1 ? 1.0 : 0.9));
		col = mix(col, vec3(0.03, 0.07, 0.13) * (hc == 1 ? 0.0 : 1.0), clamp(1.1 - e_coast + 0.5, 0.0, 1.0) * 0.85);
		col = mix(col, vec3(0.93, 0.25, 0.20), clamp(1.8 - e_war + 0.5, 0.0, 1.0));
		col = mix(col, vec3(0.95, 0.77, 0.32), clamp(1.5 - e_hi + 0.5, 0.0, 1.0));            // pick screen: the chosen nation's outline in brass
		col = mix(col, vec3(0.95, 0.77, 0.32), clamp(1.5 - e_tgt + 0.5, 0.0, 1.0));           // brass outline round valid targets
		// ---- hover (2 px brass, inside the province) and selection (3 px cream inside + 1 px ink outside; 3 + 2 px in high contrast): static, no glow
		if (quality >= 1 && hover_id > 0 && hover_id != sel_id && hover_t > 0.01) {
			float hw = 2.0 * hcm;
			float rh = ring_of(t, ex, ey, id, hover_id, hq, hw, 0.0);
			if (rh == 1.0) col = mix(col, vec3(0.949, 0.773, 0.322), hover_t);
		}
		if (quality >= 1 && sel_id > 0) {
			float rs = ring_of(t, ex, ey, id, sel_id, hq, hc == 1 ? 3.0 : 3.0, hc == 1 ? 2.0 : 1.0);
			if (rs == 1.0) col = mix(col, vec3(0.953, 0.914, 0.824), sel_t);
			else if (rs == 2.0) col = mix(col, vec3(0.137, 0.102, 0.067), sel_t);
		}

		float a = 1.0;
		if (mode == 0) {
			vec3 L = normalize(vec3(-0.35, 0.40, 0.85));
			float nl = max(dot(n, L), 0.0);
			if (hc == 1) col *= 0.88 + 0.14 * nl;
			else col *= (theme == 1) ? (0.80 + 0.3 * nl) : (0.50 + 0.62 * nl);
			col *= hc == 1 ? 1.0 : mix(0.78, 1.0, n.z);       // limb darkening
			float r = length(n.xy);
			col += vec3(0.28, 0.38, 0.52) * smoothstep(0.88, 1.0, r) * (hc == 1 ? 0.0 : 0.28);   // rim glow
			a = smoothstep(1.0, 0.994, r);
			col = mix(bg_color.rgb, col, a);
		}
		COLOR = vec4(col, 1.0);
	}
}
