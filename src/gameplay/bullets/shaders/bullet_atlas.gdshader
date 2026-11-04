shader_type canvas_item;
// Picks one cell of the bullet atlas per MultiMesh instance (ADR-0001 D4).
//
// The shape index rides in INSTANCE_CUSTOM.x, which BulletRenderer already
// packs, so a field of 2,000 bullets of four different shapes is still ONE
// draw call. The cell is tinted by INSTANCE_CUSTOM-free COLOR, which is where
// the art bible's locked 225-265 degree fill hue comes from (4.3).

// How many cells the atlas holds, left to right.
uniform int cells = 4;

void vertex() {
	// Map this quad's 0..1 UV into its own cell of the strip.
	float index = floor(INSTANCE_CUSTOM.x + 0.5);
	float width = 1.0 / float(cells);
	UV = vec2(UV.x * width + index * width, UV.y);
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// The atlas is white-on-transparent; COLOR carries the per-shape tint.
	COLOR = vec4(texel.rgb * COLOR.rgb, texel.a * COLOR.a);
}
