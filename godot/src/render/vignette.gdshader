// the demo's .vig: radial-gradient(ellipse at 50% 50%, transparent 55%, rgba(2,4,8,.7) 100%) laid over the map (under the interface)
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float e = length((UV - 0.5) * 2.0) / 1.41421356;      // farthest-corner ellipse
	float a = 0.7 * clamp((e - 0.55) / 0.45, 0.0, 1.0);
	COLOR = vec4(2.0 / 255.0, 4.0 / 255.0, 8.0 / 255.0, a);
}
