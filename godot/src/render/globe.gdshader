// Whole map in ONE fragment shader: orthographic globe or flat equirect, province borders,
// lens colours (via palette texture), selection/hover, hatch for occupied land, atmosphere.
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
uniform int quality = 2;         // 0 low (no province borders), 1 medium, 2 high
uniform float time = 0.0;
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

void fragment() {
	vec2 p = UV * rect_size;
	float lon, lat;
	vec3 n;
	if (!unproject(p, lon, lat, n)) {
		vec3 c = bg_color.rgb;
		if (mode == 0) {
			float r = length((p - rect_size * 0.5) / radius);
			float glow = smoothstep(1.14, 1.0, r);
			c += vec3(0.16, 0.27, 0.46) * glow * 0.5;
		}
		COLOR = vec4(c, 1.0);
	} else {
		vec2 t = tex_coord(lon, lat);
		ivec2 ti = ivec2(floor(t));
		vec2 f = t - floor(t);
		int id = (quality >= 2) ? smooth_id(t) : id_at(ti);

		// texels per screen pixel (finite differences; robust at the lon seam)
		float lon1, lat1; vec3 n1;
		vec2 dtx = vec2(0.0), dty = vec2(0.0);
		if (unproject(p + vec2(1.0, 0.0), lon1, lat1, n1)) dtx = wrap_dt(tex_coord(lon1, lat1) - t);
		if (unproject(p + vec2(0.0, 1.0), lon1, lat1, n1)) dty = wrap_dt(tex_coord(lon1, lat1) - t);
		float tpp = max(max(length(dtx), length(dty)), 0.0001);

		vec3 col;
		if (id == 0) {
			float lat_d = degrees(lat), lon_d = degrees(lon);
			col = mix(vec3(0.045, 0.11, 0.24), vec3(0.07, 0.17, 0.34), clamp(1.0 - abs(lat) / (PI * 0.5), 0.0, 1.0));
			if (theme == 1) col = mix(vec3(0.62, 0.70, 0.72), vec3(0.70, 0.76, 0.76), clamp(1.0 - abs(lat) / (PI * 0.5), 0.0, 1.0));
			// faint graticule every 15 degrees
			float gl = min(abs(fract(lat_d / 15.0 + 0.5) - 0.5) * 15.0, abs(fract(lon_d / 15.0 + 0.5) - 0.5) * 15.0 * cos(lat));
			col += vec3(0.05, 0.09, 0.16) * (1.0 - smoothstep(0.0, tpp * 0.18 + 0.01, gl)) * 0.6;
		} else {
			col = texelFetch(pal, ivec2(id, 0), 0).rgb;
			vec4 occ = texelFetch(pal, ivec2(id, 2), 0);
			if (occ.a > 0.5 && mod(p.x + p.y, 8.0) < 4.0) col = occ.rgb;
			if (texelFetch(pal, ivec2(id, 3), 0).r > 0.5) col = mix(col, vec3(1.0, 0.82, 0.18), 0.46 + 0.12 * sin(time * 4.0));   // valid move/attack target (breathing)
			if (id == sel_id) col = mix(col, vec3(1.0, 0.92, 0.55), (0.30 + 0.07 * sin(time * 3.0)) * sel_t);
			if (id == hover_id) col = mix(col, vec3(1.0), 0.17 * hover_t);
			if (id == hover_prev) col = mix(col, vec3(1.0), 0.17 * hover_prev_t);
		}

		if (theme == 1 && id != 0) col = mix(col, vec3(0.86, 0.76, 0.55) * (0.55 + 0.9 * dot(col, vec3(0.33))), 0.62);   // aged-paper wash
		// ---- borders (constant screen width) ----
		float e_nat = 1e4, e_prov = 1e4, e_coast = 1e4, e_sel = 1e4, e_war = 1e4, e_hov = 1e4;
		int own = owner_of(id);
		float fl = flags_of(id);
		if (quality >= 2 && id != 0) {
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
		if (quality >= 2) {
			// screen-space: compare smoothed ids one pixel to the right / below
			int nids[2] = int[2](smooth_id(t + dtx), smooth_id(t + dty));
			for (int i = 0; i < 2; i++) {
				int nid = nids[i];
				if (nid == id) continue;
				float d = 0.0;
				if (id == sel_id || nid == sel_id) e_sel = min(e_sel, d);
				if (id == hover_id || nid == hover_id) e_hov = min(e_hov, d);
				if (id == 0 || nid == 0) { e_coast = min(e_coast, d); continue; }
				int nown = owner_of(nid);
				if (nown != own) {
					e_nat = min(e_nat, d);
					float nfl = flags_of(nid);
					if ((fl >= 2.0 && nfl == 1.0) || (nfl >= 2.0 && fl == 1.0)) e_war = min(e_war, d);
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
				if (id == sel_id || nid == sel_id) e_sel = min(e_sel, d);
				if (id == hover_id || nid == hover_id) e_hov = min(e_hov, d);
				if (id == 0 || nid == 0) { e_coast = min(e_coast, d); continue; }
				int nown = owner_of(nid);
				if (nown != own) {
					e_nat = min(e_nat, d);
					float nfl = flags_of(nid);
					if ((fl >= 2.0 && nfl == 1.0) || (nfl >= 2.0 && fl == 1.0)) e_war = min(e_war, d);
				} else if (quality > 0) {
					e_prov = min(e_prov, d);
				}
			}
		}
		float prov_alpha = clamp(2.2 - tpp, 0.0, 1.0) * 0.45;
		col = mix(col, col * 0.55, clamp(0.5 + 0.8 - e_prov, 0.0, 1.0) * prov_alpha);
		vec3 nat_line = (theme == 1) ? vec3(0.30, 0.18, 0.08) : vec3(0.04, 0.05, 0.07);
		col = mix(col, nat_line, clamp(1.4 - e_nat + 0.5, 0.0, 1.0) * 0.9);
		col = mix(col, vec3(0.03, 0.07, 0.13), clamp(1.1 - e_coast + 0.5, 0.0, 1.0) * 0.85);
		col = mix(col, vec3(0.93, 0.25, 0.20), clamp(1.8 - e_war + 0.5, 0.0, 1.0));
		col = mix(col, vec3(1.0, 0.97, 0.85), clamp(1.3 - e_hov + 0.5, 0.0, 1.0) * 0.5 * hover_t * (hover_id == sel_id ? 0.0 : 1.0));
		col = mix(col, vec3(1.0, 0.85, 0.30), clamp(1.6 + 0.35 * sel_t - e_sel + 0.5, 0.0, 1.0) * sel_t);

		float a = 1.0;
		if (mode == 0) {
			vec3 L = normalize(vec3(-0.35, 0.40, 0.85));
			float nl = max(dot(n, L), 0.0);
			col *= (theme == 1) ? (0.80 + 0.3 * nl) : (0.50 + 0.62 * nl);
			col *= mix(0.78, 1.0, n.z);       // limb darkening
			float r = length(n.xy);
			col += vec3(0.28, 0.38, 0.52) * smoothstep(0.88, 1.0, r) * 0.28;   // rim glow
			a = smoothstep(1.0, 0.994, r);
			col = mix(bg_color.rgb, col, a);
		}
		COLOR = vec4(col, 1.0);
	}
}
