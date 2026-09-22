#ifndef IRIS_SPHERE_LIB_RENDER_OUTLINE_VERTEX_GLSL
#define IRIS_SPHERE_LIB_RENDER_OUTLINE_VERTEX_GLSL 1
#include "/lib/config/appearance.glsl"
#include "/lib/common/uniforms.glsl"

out vec4 vertexColor;

void main() {
    vertexColor = gl_Color;

#if defined(MC_VERSION) && MC_VERSION >= 11700
    vec4 startClip = gl_ModelViewMatrix * gl_Vertex;
    vec4 endClip = gl_ModelViewMatrix * (gl_Vertex + vec4(gl_Normal, 0.0));

    startClip.xyz *= OUTLINE_VIEW_SCALE;
    endClip.xyz *= OUTLINE_VIEW_SCALE;
    startClip = gl_ProjectionMatrix * startClip;
    endClip = gl_ProjectionMatrix * endClip;

    vec2 viewportSize = max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec2 screenDirection = (endClip.xy / max(abs(endClip.w), 1e-6) - startClip.xy / max(abs(startClip.w), 1e-6)) * viewportSize;
    float directionLength = length(screenDirection);

    screenDirection = directionLength > 1e-6 ? screenDirection / directionLength : vec2(1.0, 0.0);
    vec2 pixelOffset = vec2(-screenDirection.y, screenDirection.x) * OUTLINE_WIDTH_PIXELS / viewportSize;
    startClip.xy += ((gl_VertexID & 1) == 0 ? pixelOffset : -pixelOffset) * startClip.w;
    
    gl_Position = startClip;
#else
    gl_Position = ftransform();
#endif
}

#endif
