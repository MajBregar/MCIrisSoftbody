#ifndef IRIS_SPHERE_LIB_RENDER_SPHERE_GLSL
#define IRIS_SPHERE_LIB_RENDER_SPHERE_GLSL 1

#include "/lib/common/uniforms.glsl"
#include "/lib/config/settings.glsl"
#include "/lib/config/appearance.glsl"
#include "/lib/data/buffers.glsl"
in vec2 texcoord;
/* RENDERTARGETS:5,4 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out float outSphereDepth;
#include "/lib/config/sphere_targets.glsl"
vec3 unproject(vec2 uv, float depth) {
    vec4 homogeneousPosition = gbufferProjectionInverse * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return homogeneousPosition.xyz / homogeneousPosition.w;
}

bool boxHit(vec3 rayOrigin, vec3 rayDirection) {
    float enter = 0.0, leave = 1e20;
    for (int componentIndex = 0; componentIndex < 3; ++componentIndex) {
        if (abs(rayDirection[componentIndex]) < 1e-8) {
            if (rayOrigin[componentIndex] < meshBoundsMin[componentIndex] ||
                rayOrigin[componentIndex] > meshBoundsMax[componentIndex])
                return false;
        } else {
            float minimumPlaneDistance =
                (meshBoundsMin[componentIndex] - rayOrigin[componentIndex]) / rayDirection[componentIndex];
            float maximumPlaneDistance =
                (meshBoundsMax[componentIndex] - rayOrigin[componentIndex]) / rayDirection[componentIndex];
            enter = max(enter, min(minimumPlaneDistance, maximumPlaneDistance));
            leave = min(leave, max(minimumPlaneDistance, maximumPlaneDistance));
        }
    }
    return leave >= enter;
}

bool triangleHit(vec3 rayOrigin, vec3 rayDirection, vec3 triangleA, vec3 triangleB, vec3 triangleC,
                 out float hitDistance, out vec2 barycentric) {
    vec3 edgeAB = triangleB - triangleA;
    vec3 edgeAC = triangleC - triangleA;
    vec3 crossDirection = cross(rayDirection, edgeAC);
    float determinant = dot(edgeAB, crossDirection);
    if (abs(determinant) < 1e-8)
        return false;
    float inverseDeterminant = 1.0 / determinant;
    vec3 originOffset = rayOrigin - triangleA;
    float barycentricB = dot(originOffset, crossDirection) * inverseDeterminant;
    if (barycentricB < 0.0 || barycentricB > 1.0)
        return false;
    vec3 crossOffset = cross(originOffset, edgeAB);
    float barycentricC = dot(rayDirection, crossOffset) * inverseDeterminant;
    if (barycentricC < 0.0 || barycentricB + barycentricC > 1.0)
        return false;
    hitDistance = dot(edgeAC, crossOffset) * inverseDeterminant;
    barycentric = vec2(barycentricB, barycentricC);
    return hitDistance > 0.0;
}

void main() {
    outColor = vec4(0.0);
    outSphereDepth = 1.0;
    vec3 nearView = unproject(texcoord, 0.0);
    vec3 viewRayDirection = normalize(nearView);
    vec3 rayOrigin = (gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 rayDirection = normalize(mat3(gbufferModelViewInverse) * viewRayDirection);
    if (!boxHit(rayOrigin, rayDirection))
        return;
    float closestDistance = length(unproject(texcoord, 1.0));
    int closestTriangleIndex = -1;
    vec2 closestBarycentric = vec2(0.0);
    for (int triangleIndex = 0; triangleIndex < TRIANGLE_COUNT; ++triangleIndex) {
        uvec3 triangleIndices = texelFetch(sphereIndices, ivec2(triangleIndex, 0), 0).xyz;
        float hitDistance;
        vec2 candidateBarycentric;
        if (triangleHit(rayOrigin, rayDirection, particlePositions[triangleIndices.x].xyz,
                        particlePositions[triangleIndices.y].xyz, particlePositions[triangleIndices.z].xyz,
                        hitDistance, candidateBarycentric) &&
            hitDistance >= length(nearView) && hitDistance < closestDistance) {
            closestDistance = hitDistance;
            closestTriangleIndex = triangleIndex;
            closestBarycentric = candidateBarycentric;
        }
    }
    if (closestTriangleIndex < 0)
        return;
    vec3 hitPosition = rayOrigin + rayDirection * closestDistance;
    vec4 clipPosition = gbufferProjection * gbufferModelView * vec4(hitPosition, 1.0);
    if (clipPosition.w <= 0.0)
        return;
    float depth = clipPosition.z / clipPosition.w * 0.5 + 0.5;
    if (depth < 0.0 || depth > 1.0)
        return;
    outSphereDepth = depth;
    uvec3 triangleIndices = texelFetch(sphereIndices, ivec2(closestTriangleIndex, 0), 0).xyz;
    vec3 barycentricWeights = vec3(1.0 - closestBarycentric.x - closestBarycentric.y, closestBarycentric);
    vec3 surfaceNormal;
#if SMOOTH_NORMALS == 1
    surfaceNormal = particleNormals[triangleIndices.x].xyz * barycentricWeights.x +
                    particleNormals[triangleIndices.y].xyz * barycentricWeights.y +
                    particleNormals[triangleIndices.z].xyz * barycentricWeights.z;
#else
    surfaceNormal =
        cross(particlePositions[triangleIndices.y].xyz - particlePositions[triangleIndices.x].xyz,
              particlePositions[triangleIndices.z].xyz - particlePositions[triangleIndices.x].xyz);
#endif
    surfaceNormal = normalize(mat3(gbufferModelView) * surfaceNormal);
    if (dot(surfaceNormal, viewRayDirection) > 0.0)
        surfaceNormal = -surfaceNormal;
    float diffuse = max(dot(surfaceNormal, normalize(KEY_LIGHT_DIRECTION)), 0.0);
    vec3 color = BALL_BASE_COLOR * (AMBIENT_LIGHT + DIFFUSE_LIGHT * diffuse);
#if SHOW_VERTICES == 1
    if (min(barycentricWeights.x, min(barycentricWeights.y, barycentricWeights.z)) <
        WIREFRAME_BARYCENTRIC_WIDTH)
        color *= WIREFRAME_BRIGHTNESS;
    for (int componentIndex = 0; componentIndex < 3; ++componentIndex) {
        if (distance(hitPosition, particlePositions[triangleIndices[componentIndex]].xyz) <
            VERTEX_MARKER_RADIUS) {
            color = particlePositions[triangleIndices[componentIndex]].w > 0.5 ? CONTACT_MARKER_COLOR
                                                                               : FREE_MARKER_COLOR;
        }
    }
#endif

    if (captureStatus.overflow != 0u || captureStatus.outsideSimulationRange != 0u ||
        captureStatus.numericalFault != 0u)
        color = SIMULATION_WARNING_COLOR;
    outColor = vec4(color, 1.0);
}

#endif
