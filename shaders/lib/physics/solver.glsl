#ifndef IRIS_SPHERE_LIB_PHYSICS_SOLVER_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_SOLVER_GLSL 1

#include "/lib/common/uniforms.glsl"
#include "/lib/config/settings.glsl"
#include "/lib/data/buffers.glsl"
#include "/lib/physics/target.glsl"
#include "/lib/data/edge_colors.glsl"
#include "/lib/physics/collision.glsl"
#include "/lib/physics/entities.glsl"
#include "/lib/physics/fluids.glsl"
layout(local_size_x = SOLVER_WORKGROUP_SIZE) in;
const ivec3 workGroups = ivec3(1, 1, 1);
#include "/lib/physics/solver_state.glsl"
#include "/lib/physics/reduction.glsl"
#include "/lib/common/math.glsl"
#include "/lib/physics/constraints.glsl"

void main() {
    int particleIndex = int(gl_LocalInvocationID.x);
    bool activeParticle = particleIndex < VERTEX_COUNT;
    vec3 cameraOffset = previousCameraPosition - cameraPosition;
    if (particleIndex == 0) {
        resetRequested = needsReset(0) ? 1 : 0;
        previousTetherPosition =
            resetRequested != 0 ? targetCenter() : previousTetherTarget.xyz + cameraOffset;
        float availableTime = min(solverClock.x + clamp(frameTime, 0.0, MAX_FRAME_INTERVAL),
                                  float(MAX_PHYSICS_SUBSTEPS) * PHYSICS_TIMESTEP);
        scheduledSubsteps = resetRequested != 0 ? 0 : int(floor((availableTime + 1e-7) / PHYSICS_TIMESTEP));
        solverClock.x =
            resetRequested != 0 ? 0.0 : max(0.0, availableTime - float(scheduledSubsteps) * PHYSICS_TIMESTEP);
        solverClock.y += float(scheduledSubsteps) * PHYSICS_TIMESTEP;
        solverClock.z = float(scheduledSubsteps);
    }
    barrier();
    vec3 velocity = vec3(0.0);
    float contactState = activeParticle ? max(0.0, particlePositions[particleIndex].w) : 0.0;
    if (activeParticle) {
        predictedParticles[particleIndex] =
            vec4(resetRequested != 0 ? targetPosition(particleIndex)
                                     : particlePositions[particleIndex].xyz + cameraOffset,
                 1.0);
        velocity = resetRequested != 0 ? initialVelocity() : particleVelocities[particleIndex].xyz;
        predictedParticles[particleIndex].w = resetRequested != 0 ? 1.0 : particleVelocities[particleIndex].w;
    }
    barrier();
    ContactManifold contacts = emptyContacts();

    bool simulationBlocked = captureStatus.overflow != 0u || captureStatus.outsideSimulationRange != 0u;
    if (simulationBlocked) {
        velocity = vec3(0.0);
        contactState = 1.0;
    }
    int substepCount = simulationBlocked ? 0 : scheduledSubsteps;
    for (int substep = 0; substep < substepCount; ++substep) {
        vec3 substepStart = activeParticle ? predictedParticles[particleIndex].xyz : vec3(0.0);
        vec3 lastSafePosition = substepStart;
        contactState = 0.0;
        for (int edgeIndex = particleIndex; edgeIndex < EDGE_COUNT; edgeIndex += SOLVER_WORKGROUP_SIZE)
            distanceMultipliers[edgeIndex] = 0.0;
        if (particleIndex == 0) {
            volumeMultiplier = 0.0;
            tetherMultiplier = vec3(0.0);
        }
        if (activeParticle && predictedParticles[particleIndex].w > 0.0) {
            vec2 currentVelocity;
            vec2 fluidResponse = fluidAt(substepStart, currentVelocity);
            velocity +=
                vec3(0.0, STANDARD_GRAVITY * BUOYANCY_STRENGTH * fluidResponse.x - solverGravity, 0.0) *
                PHYSICS_TIMESTEP;

            vec3 flowVelocity = vec3(currentVelocity.x, 0.0, currentVelocity.y);
            velocity = flowVelocity +
                       (velocity - flowVelocity) * exp(-fluidResponse.y * fluidResponse.x * PHYSICS_TIMESTEP);
            velocity = limitVectorLength(velocity, MAX_PARTICLE_SPEED);
            predictedParticles[particleIndex].xyz =
                collide(substepStart, substepStart + velocity * PHYSICS_TIMESTEP, contacts, contactState);
            lastSafePosition = predictedParticles[particleIndex].xyz;
        }
        barrier();
        vec3 tetherTarget =
            mix(previousTetherPosition, targetCenter(), float(substep + 1) / float(substepCount));
        for (int iteration = 0; iteration < SOLVER_ITERATIONS; ++iteration) {
            vec4 particleTotals =
                sumWorkgroup(activeParticle ? predictedParticles[particleIndex] : vec4(0.0));
            vec3 bodyCenter = particleTotals.xyz / float(VERTEX_COUNT);
            solveTetherConstraint(particleIndex, activeParticle, particleTotals, bodyCenter, tetherTarget);
            solveDistanceConstraints(particleIndex);
            solveVolumeConstraint(particleIndex, activeParticle, bodyCenter);
            if (activeParticle) {

                vec3 proposedPosition =
                    lastSafePosition +
                    limitVectorLength(predictedParticles[particleIndex].xyz - lastSafePosition,
                                      MAX_POSITION_CORRECTION);
                proposedPosition =
                    clamp(proposedPosition, captureBoundsMin.xyz + CONTACT_MARGIN + CAPTURE_SAFETY_MARGIN,
                          captureBoundsMax.xyz - CONTACT_MARGIN - CAPTURE_SAFETY_MARGIN);
                predictedParticles[particleIndex].xyz =
                    collide(lastSafePosition, proposedPosition, contacts, contactState);
                lastSafePosition = predictedParticles[particleIndex].xyz;
            }
            barrier();
        }

        vec4 bodyTotal =
            sumWorkgroup(activeParticle ? vec4(predictedParticles[particleIndex].xyz, 0.0) : vec4(0.0));
        if (particleIndex == 0)
            entityProximityContact = entityRepulsion(bodyTotal.xyz / float(VERTEX_COUNT));
        barrier();
        if (activeParticle && predictedParticles[particleIndex].w > 0.0) {
            vec3 positionBeforeEntityCorrection = predictedParticles[particleIndex].xyz;
            if (entityProximityContact.w > 0.0) {
                vec3 correctionStart = predictedParticles[particleIndex].xyz;
                vec3 proposedPosition =
                    correctionStart +
                    entityProximityContact.xyz * min(entityProximityContact.w, MAX_POSITION_CORRECTION);
                proposedPosition =
                    clamp(proposedPosition, captureBoundsMin.xyz + CONTACT_MARGIN + CAPTURE_SAFETY_MARGIN,
                          captureBoundsMax.xyz - CONTACT_MARGIN - CAPTURE_SAFETY_MARGIN);
                predictedParticles[particleIndex].xyz =
                    collide(correctionStart, proposedPosition, contacts, contactState);
                contactState = 1.0;
            }

            // Position separation is full-strength; transfer controls only its velocity contribution.
            vec3 entityCorrection = predictedParticles[particleIndex].xyz - positionBeforeEntityCorrection;
            velocity = (positionBeforeEntityCorrection - substepStart +
                        clamp(ENTITY_BOUNCE_TRANSFER, 0.0, 1.0) * entityCorrection) /
                       PHYSICS_TIMESTEP;
            if (entityProximityContact.w > 0.0)
                velocity -= entityProximityContact.xyz * min(0.0, dot(velocity, entityProximityContact.xyz));
            velocity = projectContactMotion(velocity, contacts);
            velocity =
                limitVectorLength(velocity * exp(-solverDamping * PHYSICS_TIMESTEP), MAX_PARTICLE_SPEED);
            if (any(isnan(predictedParticles[particleIndex].xyz)) ||
                any(isinf(predictedParticles[particleIndex].xyz)) || any(isnan(velocity)) ||
                any(isinf(velocity))) {
                predictedParticles[particleIndex].xyz = substepStart;
                velocity = vec3(0.0);
                atomicOr(captureStatus.numericalFault, 1u);
            }
        }
        barrier();
    }
    if (activeParticle) {
        particlePositions[particleIndex] = vec4(predictedParticles[particleIndex].xyz, contactState);
        particleVelocities[particleIndex] = vec4(velocity, predictedParticles[particleIndex].w);
    }
    if (particleIndex == 0)
        previousTetherTarget = vec4(targetCenter(), 1.0);
}

#endif
