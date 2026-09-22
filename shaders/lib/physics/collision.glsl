#ifndef IRIS_SPHERE_LIB_PHYSICS_COLLISION_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_COLLISION_GLSL 1

// Sweep each accepted displacement, including sliding; temporary contacts are per query.
#include "/lib/config/constants.glsl"

struct ContactManifold {
    vec3 normals[LOCAL_CONTACT_COUNT];
    int count;
};
ContactManifold emptyContacts() {
    ContactManifold contacts;
    contacts.count = 0;
    for (int contactIndex = 0; contactIndex < LOCAL_CONTACT_COUNT; ++contactIndex)
        contacts.normals[contactIndex] = vec3(0.0);
    return contacts;
}

bool addContact(vec3 surfaceNormal, inout ContactManifold contacts) {
    for (int contactIndex = 0; contactIndex < contacts.count; ++contactIndex)
        if (dot(surfaceNormal, contacts.normals[contactIndex]) > 0.99999) {
            contacts.normals[contactIndex] = surfaceNormal;
            return true;
        }
    if (contacts.count == LOCAL_CONTACT_COUNT)
        return false;
    contacts.normals[contacts.count++] = surfaceNormal;
    return true;
}

bool insideTriangle(vec3 position, vec3 triangleA, vec3 triangleB, vec3 triangleC) {
    vec3 edgeAB = triangleB - triangleA, edgeAC = triangleC - triangleA, pointOffset = position - triangleA;
    float edgeABLengthSquared = dot(edgeAB, edgeAB), edgeDotProduct = dot(edgeAB, edgeAC),
          edgeACLengthSquared = dot(edgeAC, edgeAC);
    float determinant = edgeABLengthSquared * edgeACLengthSquared - edgeDotProduct * edgeDotProduct;
    if (determinant <= 1e-14)
        return false;
    float barycentricB =
        (edgeACLengthSquared * dot(pointOffset, edgeAB) - edgeDotProduct * dot(pointOffset, edgeAC)) /
        determinant;
    float barycentricC =
        (edgeABLengthSquared * dot(pointOffset, edgeAC) - edgeDotProduct * dot(pointOffset, edgeAB)) /
        determinant;
    return min(barycentricB, barycentricC) >= -1e-6 && barycentricB + barycentricC <= 1.000001;
}

vec3 closestSegment(vec3 position, vec3 segmentStart, vec3 segmentEnd) {
    vec3 segment = segmentEnd - segmentStart;
    return segmentStart +
           segment *
               clamp(dot(position - segmentStart, segment) / max(dot(segment, segment), 1e-20), 0.0, 1.0);
}

vec3 closestTriangle(vec3 position, vec3 triangleA, vec3 triangleB, vec3 triangleC) {
    vec3 surfaceNormal = normalize(cross(triangleB - triangleA, triangleC - triangleA));
    vec3 projectedPoint = position - surfaceNormal * dot(position - triangleA, surfaceNormal);
    if (insideTriangle(projectedPoint, triangleA, triangleB, triangleC))
        return projectedPoint;
    vec3 closestAB = closestSegment(position, triangleA, triangleB),
         closestBC = closestSegment(position, triangleB, triangleC),
         closestCA = closestSegment(position, triangleC, triangleA);
    float distanceABSquared = dot(position - closestAB, position - closestAB),
          distanceBCSquared = dot(position - closestBC, position - closestBC),
          distanceCASquared = dot(position - closestCA, position - closestCA);
    return distanceABSquared <= distanceBCSquared && distanceABSquared <= distanceCASquared ? closestAB
           : distanceBCSquared <= distanceCASquared                                         ? closestBC
                                                                                            : closestCA;
}

bool feasibleMotion(vec3 motion, ContactManifold contacts) {
    for (int contactIndex = 0; contactIndex < LOCAL_CONTACT_COUNT; ++contactIndex)
        if (contactIndex < contacts.count && dot(motion, contacts.normals[contactIndex]) < -1e-9)
            return false;
    return true;
}

vec3 projectContactMotion(vec3 motion, ContactManifold contacts) {
    if (feasibleMotion(motion, contacts))
        return motion;
    vec3 closestAllowedMotion = vec3(0.0);
    float smallestChangeSquared = dot(motion, motion);

    // Avoid repeated zero-time hits from cancellation at grazing contacts.
    float outwardSlop = 2e-7 * length(motion);
    for (int contactIndex = 0; contactIndex < LOCAL_CONTACT_COUNT; ++contactIndex) {
        if (contactIndex >= contacts.count)
            continue;
        vec3 surfaceNormal = contacts.normals[contactIndex];
        vec3 candidate =
            motion +
            ((outwardSlop - dot(motion, surfaceNormal)) / dot(surfaceNormal, surfaceNormal)) * surfaceNormal;
        float changeSquared = dot(candidate - motion, candidate - motion);
        if (changeSquared < smallestChangeSquared && feasibleMotion(candidate, contacts)) {
            closestAllowedMotion = candidate;
            smallestChangeSquared = changeSquared;
        }
        for (int otherContactIndex = contactIndex + 1; otherContactIndex < LOCAL_CONTACT_COUNT;
             ++otherContactIndex) {
            if (otherContactIndex >= contacts.count)
                continue;
            vec3 creaseDirection = cross(surfaceNormal, contacts.normals[otherContactIndex]);
            float creaseLengthSquared = dot(creaseDirection, creaseDirection);
            if (creaseLengthSquared < 1e-10)
                continue;
            candidate = creaseDirection * (dot(motion, creaseDirection) / creaseLengthSquared);
            vec3 outward = surfaceNormal + contacts.normals[otherContactIndex];
            candidate +=
                outward *
                (outwardSlop / max(1e-10, 1.0 + dot(surfaceNormal, contacts.normals[otherContactIndex])));
            changeSquared = dot(candidate - motion, candidate - motion);
            if (changeSquared < smallestChangeSquared && feasibleMotion(candidate, contacts)) {
                closestAllowedMotion = candidate;
                smallestChangeSquared = changeSquared;
            }
        }
    }
    return closestAllowedMotion;
}

void considerHit(float hitFraction, vec3 normal, vec3 motion, inout float firstHitFraction,
                 inout vec3 hitNormal) {
    if (hitFraction >= -1e-6 && hitFraction <= 1.0 && hitFraction < firstHitFraction &&
        dot(normal, motion) < -1e-9) {
        firstHitFraction = max(0.0, hitFraction);
        hitNormal = normal;
    }
}

float firstRoot(float quadraticCoefficient, float halfLinearCoefficient, float constantCoefficient) {
    if (quadraticCoefficient < 1e-20 || halfLinearCoefficient >= 0.0)
        return 2.0;
    float discriminant =
        halfLinearCoefficient * halfLinearCoefficient - quadraticCoefficient * constantCoefficient;
    if (discriminant < 0.0)
        return 2.0;
    float denominator = -halfLinearCoefficient + sqrt(max(0.0, discriminant));
    return denominator > 1e-20 ? constantCoefficient / denominator : 2.0;
}

void sweepVertex(vec3 position, vec3 motion, vec3 vertex, float particleRadius, inout float firstHitFraction,
                 inout vec3 normal) {
    vec3 vertexOffset = position - vertex;
    float hitFraction = firstRoot(dot(motion, motion), dot(vertexOffset, motion),
                                  dot(vertexOffset, vertexOffset) - particleRadius * particleRadius);
    if (hitFraction < 0.0 || hitFraction > 1.0)
        return;
    vec3 delta = vertexOffset + hitFraction * motion;
    if (length(delta) > 1e-10)
        considerHit(hitFraction, normalize(delta), motion, firstHitFraction, normal);
}

void sweepEdge(vec3 position, vec3 motion, vec3 edgeStart, vec3 edgeEnd, float particleRadius,
               inout float firstHitFraction, inout vec3 normal) {
    vec3 edge = edgeEnd - edgeStart, edgeOffset = position - edgeStart;
    float edgeLengthSquared = dot(edge, edge);
    if (edgeLengthSquared < 1e-16)
        return;
    vec3 radialOffset = edgeOffset - edge * (dot(edgeOffset, edge) / edgeLengthSquared);
    vec3 radialMotion = motion - edge * (dot(motion, edge) / edgeLengthSquared);
    float hitFraction = firstRoot(dot(radialMotion, radialMotion), dot(radialOffset, radialMotion),
                                  dot(radialOffset, radialOffset) - particleRadius * particleRadius);
    if (hitFraction < 0.0 || hitFraction > 1.0)
        return;
    float edgeParameter = dot(edgeOffset + hitFraction * motion, edge) / edgeLengthSquared;
    if (edgeParameter < 0.0 || edgeParameter > 1.0)
        return;
    vec3 delta = radialOffset + hitFraction * radialMotion;
    if (length(delta) > 1e-10)
        considerHit(hitFraction, normalize(delta), motion, firstHitFraction, normal);
}

void sweepTriangle(vec3 position, vec3 motion, vec3 triangleA, vec3 triangleB, vec3 triangleC,
                   inout float firstHitFraction, inout vec3 normal) {
    float particleRadius = CONTACT_MARGIN;
    vec3 sweepBoundsMin = min(position, position + motion) - particleRadius - CONTACT_EPSILON,
         sweepBoundsMax = max(position, position + motion) + particleRadius + CONTACT_EPSILON;
    if (any(lessThan(sweepBoundsMax, min(triangleA, min(triangleB, triangleC)))) ||
        any(greaterThan(sweepBoundsMin, max(triangleA, max(triangleB, triangleC)))))
        return;
    vec3 delta = position - closestTriangle(position, triangleA, triangleB, triangleC);
    float distanceSquared = dot(delta, delta);

    // An undefined contact side stops this particle only. Shallow overlaps may slide or leave.
    if (distanceSquared <= 1e-20) {
        firstHitFraction = 0.0;
        normal = vec3(0.0);
        return;
    }

    if (distanceSquared <= (particleRadius + CONTACT_EPSILON) * (particleRadius + CONTACT_EPSILON))
        considerHit(0.0, delta * inversesqrt(distanceSquared), motion, firstHitFraction, normal);
    vec3 faceNormal = normalize(cross(triangleB - triangleA, triangleC - triangleA));
    for (int side = -1; side <= 1; side += 2) {
        vec3 surfaceNormal = faceNormal * float(side);
        float approachSpeed = dot(motion, surfaceNormal);
        if (approachSpeed >= -1e-9)
            continue;
        float hitFraction = (particleRadius - dot(position - triangleA, surfaceNormal)) / approachSpeed;
        if (hitFraction >= -1e-6 && hitFraction <= 1.0 &&
            insideTriangle(position + max(0.0, hitFraction) * motion - surfaceNormal * particleRadius,
                           triangleA, triangleB, triangleC))
            considerHit(hitFraction, surfaceNormal, motion, firstHitFraction, normal);
    }
    sweepEdge(position, motion, triangleA, triangleB, particleRadius, firstHitFraction, normal);
    sweepEdge(position, motion, triangleB, triangleC, particleRadius, firstHitFraction, normal);
    sweepEdge(position, motion, triangleC, triangleA, particleRadius, firstHitFraction, normal);
    sweepVertex(position, motion, triangleA, particleRadius, firstHitFraction, normal);
    sweepVertex(position, motion, triangleB, particleRadius, firstHitFraction, normal);
    sweepVertex(position, motion, triangleC, particleRadius, firstHitFraction, normal);
}

vec3 frictionMotion(vec3 motion, vec3 contactNormal) {
    float normalMotion = dot(motion, contactNormal);
    float normalCorrection = max(0.0, -normalMotion);
    vec3 tangent = motion - contactNormal * normalMotion;
    float slipDistance = length(tangent);
    if (normalCorrection > 0.0 && slipDistance > 1e-12) {
        float staticCoefficient = max(STATIC_FRICTION, DYNAMIC_FRICTION);
        float correction = slipDistance <= staticCoefficient * normalCorrection
                               ? slipDistance
                               : min(slipDistance, DYNAMIC_FRICTION * normalCorrection);
        tangent *= max(0.0, 1.0 - correction / slipDistance);
    }
    return tangent + contactNormal * max(0.0, normalMotion);
}

vec3 collide(vec3 start, vec3 goal, out ContactManifold contacts, inout float contact) {
    contacts = emptyContacts();
#if COLLISION_ENABLED == 1
    vec3 motion = goal - start;
    for (int eventIndex = 0; eventIndex < MAX_COLLISION_EVENTS; ++eventIndex) {
        motion = projectContactMotion(motion, contacts);
        float remainingDistance = length(motion);
        if (remainingDistance < 1e-9)
            return start;
        float firstHitFraction = 2.0;
        vec3 hitNormal = vec3(0.0);
        for (uint triangleIndex = 0u;
             triangleIndex < min(captureStatus.triangleCount, uint(COLLIDER_CAPACITY)); ++triangleIndex) {
            sweepTriangle(start, motion, terrainTriangleVertices[3u * triangleIndex].xyz,
                          terrainTriangleVertices[3u * triangleIndex + 1u].xyz,
                          terrainTriangleVertices[3u * triangleIndex + 2u].xyz, firstHitFraction, hitNormal);
        }
        if (firstHitFraction > 1.0)
            return start + motion;
        contact = 1.0;
        if (dot(hitNormal, hitNormal) < 0.5)
            return start;

        float safeTravelFraction = max(0.0, firstHitFraction - CONTACT_EPSILON / remainingDistance);
        start += motion * safeTravelFraction;
        motion = frictionMotion(motion * (1.0 - safeTravelFraction), hitNormal);
        if (!addContact(hitNormal, contacts))
            return start;
    }
    return start;
#else
    return goal;
#endif
}

#endif
