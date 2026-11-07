// The first title stage's globe: the whole world as one smooth flat map (assets/title/globe_flat.png, made by tools/menu_globe.py) on an orthographic sphere that turns slowly.
// Light from the upper left, a dark limb with a blue rim, a hairline gold graticule every 15 degrees, a soft glow around the disc. The picture is square; the disc fills `disc` of it.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
uniform float lon0 = 0.6;
uniform float lat0 = 0.21;
uniform float disc = 0.7692;                 // the disc's radius as a share of the half side
uniform float grat = 0.30;
uniform float alpha = 1.0;

float grid(float v, float step_) {
	float f = v / step_;
	float d = abs(f - round(f));
	float w = fwidth(f) + 1e-6;
	return clamp(1.0 - d / (w * 1.1), 0.0, 1.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float rr = length(p) / disc;
	if (rr > 1.0) {                           // the glow outside the limb
		float g = exp(-clamp(rr - 1.0, 0.0, 5.0) / 0.045) * clamp(1.0 - (rr - 1.0) / 0.30, 0.0, 1.0);
		COLOR = vec4(0.10, 0.24, 0.51, g * 0.55 * alpha);
	} else {
		vec2 d = p / disc;
		float z = sqrt(max(1.0 - rr * rr, 0.0));
		float s0 = sin(lat0), c0 = cos(lat0);
		float lat = asin(clamp(z * s0 + d.y * c0, -1.0, 1.0));
		float lon = lon0 + atan(d.x, z * c0 - d.y * s0);
		vec2 uv = vec2(lon / TAU + 0.5, clamp(0.5 - lat / PI, 0.002, 0.998));
		vec3 col = textureGrad(tex, uv, vec2(fwidth(lon) / TAU, 0.0), vec2(0.0, fwidth(lat) / PI)).rgb;
		float ocean = 1.0 - smoothstep(0.02, 0.07, length(col - vec3(10.0, 18.0, 30.0) / 255.0));
		vec3 L = normalize(vec3(-0.45, 0.55, 0.70));
		float lam = clamp(d.x * L.x + d.y * L.y + z * L.z, 0.0, 1.0);
		float shade = (0.50 + 0.62 * lam) * (0.78 + 0.22 * z);
		col *= shade;
		float sheen = pow(clamp(lam - 0.72, 0.0, 1.0) / 0.28, 2.0) * ocean;
		col += sheen * vec3(10.0, 20.0, 34.0) / 255.0;
		float lw = mod(lon + PI, TAU) - PI;
		float gl = max(grid(degrees(lw), 15.0) * step(abs(degrees(lw) - round(degrees(lw) / 15.0) * 15.0), 3.0), grid(degrees(lat), 15.0));
		gl = clamp(gl, 0.0, 1.0) * grat * (0.35 + 0.65 * z);
		col = mix(col, vec3(201.0, 162.0, 75.0) / 255.0, gl);
		float rim = pow(clamp((rr - 0.80) / 0.20, 0.0, 1.0), 2.2);
		col += rim * vec3(10.0, 26.0, 58.0) / 255.0;
		float edge = clamp((1.0 - rr) / max(fwidth(rr), 1e-5), 0.0, 1.0);
		COLOR = vec4(col, edge * alpha);
	}
}
