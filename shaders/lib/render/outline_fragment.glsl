#ifndef IRIS_SPHERE_LIB_RENDER_OUTLINE_FRAGMENT_GLSL
#define IRIS_SPHERE_LIB_RENDER_OUTLINE_FRAGMENT_GLSL 1
#include "/lib/common/uniforms.glsl"

in vec4 vertexColor;
/* RENDERTARGETS:0 */
layout(location = 0) out vec4 outColor;

void main() {
    if (gl_FragCoord.z >= texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).r)
        discard;
    outColor = vertexColor;
}

#endif
