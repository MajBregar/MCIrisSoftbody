#ifndef IRIS_SPHERE_LIB_COMMON_UNIFORMS_GLSL
#define IRIS_SPHERE_LIB_COMMON_UNIFORMS_GLSL 1

uniform float alphaTestRef;
uniform int blockEntityId;
uniform vec3 cameraPosition;
uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex1;
uniform vec4 entityColor;
uniform float frameTime;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec3 previousCameraPosition;
uniform int renderStage;
uniform mat4 shadowModelViewInverse;
uniform usampler2D sphereAdjacency;
uniform sampler2D sphereEdges;
uniform usampler2D sphereIndices;
uniform sampler2D sphereRest;
uniform float viewHeight;
uniform float viewWidth;

#endif
