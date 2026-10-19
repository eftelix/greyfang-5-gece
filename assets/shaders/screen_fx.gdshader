shader_type canvas_item;
// Full-screen post effect: security-camera feed (noise, scanlines, barrel, chroma,
// glitch bands) or subtle office grain/vignette, controlled by uniforms.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float noise_amt = 0.12;
uniform float glitch = 0.0;
uniform float barrel = 0.08;
uniform float scan_amt = 0.15;
uniform float tint_amt = 0.5;
uniform float vignette = 1.4;
uniform float dark = 0.0;
uniform vec3 tint = vec3(0.85, 1.0, 0.9);

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float band = step(0.985 - glitch * 0.35, rand(vec2(floor(uv.y * 45.0), floor(t * 14.0))));
	uv.x += band * (rand(vec2(t, floor(uv.y * 45.0))) - 0.5) * 0.09 * (0.25 + glitch);
	uv.y += glitch * 0.02 * sin(t * 50.0) * step(0.7, rand(vec2(floor(t * 8.0), 1.0)));
	vec2 cc = uv - 0.5;
	float d = dot(cc, cc);
	uv = 0.5 + cc * (1.0 + barrel * d);
	float ca = 0.0015 + glitch * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	float n = rand(floor(SCREEN_UV * vec2(480.0, 270.0)) + fract(t * 7.0) * 113.0);
	col = mix(col, vec3(n), clamp(noise_amt + glitch * 0.55, 0.0, 1.0));
	col *= 1.0 - scan_amt + scan_amt * sin(SCREEN_UV.y * 900.0);
	col *= 1.0 - d * vignette;
	col = mix(col, col * tint, tint_amt);
	col *= 1.0 - dark;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { col = vec3(0.0); }
	COLOR = vec4(col, 1.0);
}
