shader_type spatial;
render_mode unshaded;

uniform sampler2DArray s2DArray : source_color;
uniform float numberOfFrames;
uniform float aperture;
uniform float focus;

varying vec2 originalUv;
varying vec2 modifiedUv;

void vertex() {
	// Called for every vertex the material is visible on.
	vec3 relPosToCam = CAMERA_POSITION_WORLD - VERTEX;
	vec3 normDirection = normalize(relPosToCam);
	float ratio = abs(relPosToCam.z / normDirection.z);
	vec3 uvPoint = ratio * normDirection;
	originalUv = UV;
	originalUv.x = 1.0 - originalUv.x;
	modifiedUv = uvPoint.xy + 0.5;
	modifiedUv.x = 1.0 - modifiedUv.x;
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 color = vec4(0.0);
	float colorCount = 0.0;
	if (modifiedUv.x < 0.0 || modifiedUv.y < 0.0 || modifiedUv.x > 1.0 || modifiedUv.y > 1.0) {
		discard;
	}
	vec2 satModUv = clamp(modifiedUv, 0.0, 1.0);
	
	for (float i = 0.0; i < numberOfFrames; i++) {
		float dx = 0.5 - originalUv.x * numberOfFrames + i;
		float dy = 0.5 - originalUv.y;
		float squareDistance = dx * dx + dy * dy;
		if (squareDistance < aperture) {
			vec2 focusOffset = vec2(dx, dy) * focus;
			color += texture(s2DArray, vec3(satModUv + focusOffset, i));
			colorCount += 1.0;
		}
	}
	
	ALBEDO = color.rgb / colorCount;
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
