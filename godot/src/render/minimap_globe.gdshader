// Mini-globe for the corner minimap: the minimap's equirect texture on an orthographic sphere, turned exactly like the main globe (same lon0/lat0 maths as globe.gdshader).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : filter_linear, repeat_enable;
uniform float lon0 = 0.0;
uniform float lat0 = 0.3;
uniform float view_r = 0.0;                    // sine of the main view's angular radius (0 hides the ring)
uniform vec4 brass : source_color = vec4(0.9, 0.78, 0.48, 1.0);
uniform vec4 rim : source_color = vec4(0.45, 0.62, 0.85, 1.0);
uniform float grat = 0.16;                    // graticule strength

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	d.y = -d.y;
	float r = min(length(d), 0.9999);
	float z = sqrt(1.0 - r * r);
	float s0 = sin(lat0), c0 = cos(lat0);
	float lat = asin(clamp(z * s0 + d.y * c0, -1.0, 1.0));
	float lon = lon0 + atan(d.x, z * c0 - d.y * s0);
	vec2 uv = vec2(lon / TAU + 0.5, clamp(0.5 - lat / PI, 0.003, 0.997));
	vec3 c = texture(tex, uv).rgb;
	// key light from the upper left, soft terminator toward the lower right
	float lit = 0.80 + 0.36 * clamp(dot(normalize(vec3(-0.45, 0.55, 0.7)), vec3(d, z)), -0.2, 1.0);
	c = c * lit + vec3(0.02, 0.04, 0.07);
	// graticule every 30 degrees (meridians fade toward the poles so they do not pile up)
	float gl = abs(fract(lat / (PI / 6.0) + 0.5) - 0.5);
	float gm = abs(fract(lon / (PI / 6.0) + 0.5) - 0.5);
	float cl = max(cos(lat), 0.2);
	float line = max(1.0 - smoothstep(0.0, 0.035, gl), (1.0 - smoothstep(0.0, 0.035 / cl, gm)) * step(abs(lat), 1.3));
	c = mix(c, vec3(0.85, 0.8, 0.65), line * grat);
	// atmosphere: blue at the limb
	float limb = smoothstep(0.72, 1.0, r);
	c = mix(c, rim.rgb * 0.9, limb * 0.5);
	float a = 1.0 - smoothstep(0.975, 0.9999, r);
	// the main view: a ring on the sphere around its centre (the minimap turns with the main globe), plus a centre dot
	if (view_r > 0.0) {
		float w = 0.028;
		float ring = 1.0 - smoothstep(w * 0.5, w, abs(r - view_r));
		c = mix(c, brass.rgb, ring * 0.95);
	}
	float dot_ = 1.0 - smoothstep(0.02, 0.05, r);
	c = mix(c, brass.rgb, dot_ * 0.9);
	COLOR = vec4(c, a);
}
