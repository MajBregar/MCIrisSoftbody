#ifndef IRIS_SPHERE_LIB_RENDER_MATERIAL_FRAGMENT_GLSL
#define IRIS_SPHERE_LIB_RENDER_MATERIAL_FRAGMENT_GLSL 1
#include "/lib/common/uniforms.glsl"

in vec2 texcoord;
in vec2 lmcoord;
in vec4 vertexColor;
/* RENDERTARGETS:0 */
layout(location = 0) out vec4 outColor;

void main() {

#ifdef TEST_SPHERE_DEPTH
    if (gl_FragCoord.z >= texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0).r)
        discard;
#endif

    vec4 surface = texture(gtexture, texcoord) * vertexColor;
    if (surface.a < alphaTestRef)
        discard;

#ifndef UNLIT_ENTITY
    surface.rgb *= texture(lightmap, lmcoord).rgb;
#ifdef APPLY_ENTITY_TINT
    surface.rgb = mix(surface.rgb, entityColor.rgb, entityColor.a);
#endif

#endif
    outColor = surface;
}

#endif
