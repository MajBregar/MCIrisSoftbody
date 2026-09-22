#ifndef IRIS_SPHERE_LIB_RENDER_COMPOSITE_GLSL
#define IRIS_SPHERE_LIB_RENDER_COMPOSITE_GLSL 1
#include "/lib/common/uniforms.glsl"

in vec2 texcoord;
/* RENDERTARGETS:0 */
layout(location = 0) out vec4 outColor;

void main() {
    outColor = texture(colortex0, texcoord);
    float sphereDepth = texture(colortex4, texcoord).r;
    
    if (sphereDepth < texture(depthtex1, texcoord).r) {
        outColor = texture(colortex5, texcoord);
    }
}

#endif
