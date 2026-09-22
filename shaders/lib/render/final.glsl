#ifndef IRIS_SPHERE_LIB_RENDER_FINAL_GLSL
#define IRIS_SPHERE_LIB_RENDER_FINAL_GLSL 1
#include "/lib/common/uniforms.glsl"

in vec2 texcoord;
layout(location = 0) out vec4 outColor;

void main() {
    outColor = texture(colortex0, texcoord);
}

#endif
