#ifndef IRIS_SPHERE_LIB_PHYSICS_SOLVER_STATE_GLSL
#define IRIS_SPHERE_LIB_PHYSICS_SOLVER_STATE_GLSL 1

// One shared state per 256-thread solver workgroup. Padding lanes join every barrier.
#if BALL_MODE == 1
const float solverGravity = FREE_GRAVITY;
const float solverDamping = FREE_DAMPING;
#else
const float solverGravity = GRAVITY;
const float solverDamping = VELOCITY_DAMPING;
#endif
shared vec4 predictedParticles[VERTEX_COUNT];
shared float distanceMultipliers[EDGE_COUNT];
shared vec4 reductionScratch[SOLVER_WORKGROUP_SIZE];
shared float volumeMultiplier;
shared vec3 tetherMultiplier;
shared int scheduledSubsteps;
shared int resetRequested;
shared vec3 previousTetherPosition;
shared vec4 entityProximityContact;

#endif
