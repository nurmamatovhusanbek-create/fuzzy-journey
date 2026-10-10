// Mini-globe for the corner minimap (the Bezel demo's renderMM / globeSVG): the minimap's equirect texture on an orthographic sphere, turned exactly like the main view
// (same lon0/lat0 maths as globe.gdshader), a 30 degree graticule and the demo's `mmsh` shading overlay (a soft highlight upper left, a dark limb with a blue rim).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : filter_linear, repeat_enable;
uniform float lon0 = 0.0;
uniform float lat0 = 0.3;
uniform float r_units = 62.0;                  // the sphere's radius in layout units (graticule line width is 0.6 unit)
uniform vec4 grat_col : source_color = vec4(0.788, 0.749, 0.627, 1.0);   // #C9BFA0
uniform float grat = 0.16;                    // graticule opacity

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
	// graticule every 30 degrees: lines about 0.6 layout units wide (parallels to 60, meridians fade out toward the poles)
	float ppu = 1.0 / max(fwidth(UV.x) * 2.0 * r_units, 1e-5);          // physical pixels per layout unit
	float lw = max(0.6 * ppu, 1.0);
	float step_ = PI / 6.0;
	float gl = abs(fract(lat / step_ + 0.5) - 0.5);                     // triangle waves: zero on a line (continuous across the lon seam: 2 PI is 12 steps)
	float gm = abs(fract(lon / step_ + 0.5) - 0.5);
	float dl = gl / max(fwidth(gl), 1e-6);                              // distance to the line in physical pixels
	float dm = gm / max(fwidth(gm), 1e-6);
	float line = max(clamp(0.5 * lw - dl + 0.5, 0.0, 1.0) * step(abs(lat), 1.1), clamp(0.5 * lw - dm + 0.5, 0.0, 1.0) * step(abs(lat), 1.4));
	c = mix(c, grat_col.rgb, line * grat);
	// mmsh: radialGradient cx .36 cy .32 r .85 over the sphere's box: white 10 % -> clear at .55 -> #05070a 38 % at .86 -> #5E86C4 42 % at 1
	float t = length(UV - vec2(0.36, 0.32)) / 0.85;
	vec4 sh;
	if (t < 0.55) {
		float k = t / 0.55;
		sh = vec4(vec3(1.0 - k), 0.10 * (1.0 - k));
	} else if (t < 0.86) {
		float k = (t - 0.55) / 0.31;
		sh = vec4(vec3(0.0196, 0.0275, 0.0392) * k, 0.38 * k);
	} else {
		float k = clamp((t - 0.86) / 0.14, 0.0, 1.0);
		sh = vec4(mix(vec3(0.0196, 0.0275, 0.0392), vec3(0.369, 0.525, 0.769), k), mix(0.38, 0.42, k));
	}
	c = mix(c, sh.rgb, sh.a);
	float a = 1.0 - smoothstep(0.985, 0.9999, r);
	COLOR = vec4(c, a);
}
