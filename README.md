# Iris Soft Sphere

A shader-only soft sphere with GPU position-based dynamics, swept block contacts,
surface friction, entity proximity repulsion, and water/lava forces. The supplied
mesh has 162 particles, 320 triangles and 480 distance constraints.

## Install and run

1. Place `IrisSphereDemo.zip` in Minecraft's `shaderpacks` folder, or use the
   unpacked folder with `shaders/` directly inside it.
2. Select the pack in Iris. It requires compute shaders, shader storage buffers
   and OpenGL 4.3 support.
3. Open **Shader Pack Settings**. Hover over any option for its purpose, units,
   tuning direction and dependencies.

The initial ball radius is 0.75 blocks. It starts four blocks toward world -Z
from the camera and follows that offset with a center tether. Select
**Ball & Placement → Placement Axes → View Direction** to place it in front of
your view instead. Applying shader settings reloads the simulation and resets
the ball.

For a released ball, select **Ball & Placement → Ball Motion → Free Roll**.
It then uses free gravity and damping and stays in world space. Set
**Motion → Free Roll Launch Speed** to zero to drop it without an initial push.

## Settings

| Menu | Controls |
| --- | --- |
| Main screen | Simulation distance before freezing |
| Ball & Placement | Held/free mode, placement axes, radius and X/Y/Z offsets |
| Motion | Separate held/free gravity and damping, free launch speed |
| Shape & Constraints | Solver iterations, edge and volume softness, center tether and tether softness |
| Block Collisions & Friction | Solid/entity collision switch, vertex contact radius, static and sliding friction |
| Entity Proximity | Proximity response, clearance and bounce transfer coefficient |
| Water & Lava | Fluid forces, buoyancy, currents, water/lava drag and current speeds |
| Appearance | Vertex/wireframe markers and smooth surface shading |

All 33 settings have descriptions. All 24 numeric tuning controls are sliders,
with finer choices around useful values. Existing option identifiers and defaults
are preserved, so previous setting overrides still refer to the same controls.

### Tuning

- **Edge Softness** and **Volume Softness** are compliance values: smaller is
  stiffer. **Constraint Iterations** improves convergence at additional GPU cost.
- **Vertex Contact Radius** sets the clearance around each particle. The default
  is 0.015 blocks. Raising it deliberately creates a larger gap around the mesh.
- **Static Surface Friction** provides grip for rolling. **Sliding Surface
  Friction** reduces slip; usually keep it at or below static friction.
- **Entity Bounce Transfer** scales only the velocity from entity separation.
  Zero still separates positions and stops inward motion, without adding bounce.
- **Fluid Forces** controls buoyancy, drag and currents together. **Flowing Liquid
  Currents** can be disabled separately. Current strength depends on surface
  slope, the liquid's current speed, and its drag; zero drag means no current force.
- With gravity at 9.81, **Buoyancy Strength** above one supports floating. The
  default is two. Stronger gravity can make the ball sit deeper or sink.

With vertex markers enabled, red marks contact and light markers show free
particles. Yellow indicates a simulation warning: the ball is beyond the
simulation distance, geometry capture overflowed, or numerical recovery occurred.
Returning within range resumes a distance-frozen ball. Reloading resets it.

## Behavior and limits

Block contacts use the captured rendered triangles with an analytic swept radius
around each particle, including triangle edges and corners. Sweeps also check
constraint corrections and sliding. Contacts are temporary; there is no persistent
terrain contact cache. An ambiguous contact stops only that particle's attempted
motion. Common decorative blocks with empty game collision shapes are filtered
from physics capture without being removed from rendering.

Entity response uses a coarse half-block occupancy field rebuilt each frame;
it is approximate repulsion rather than exact entity-plane contact. Fluids use
sampled column boundaries, with explicit horizontal flow inferred from the
liquid surface slope. Deep, covered, unusual or modded geometry can differ from
gameplay collision and fluid rules: this shader has no direct access to the
Minecraft collision engine, entity velocities or authoritative fluid vectors.
The block filter contains version branches for the supported vanilla 1.20–1.21
block mappings; modded blocks can require additional mappings.

The sphere is rendered to its own color and depth textures before world drawing.
World composition, entities, translucent surfaces and selection outlines use its
depth so foreground world surfaces remain visible. The pack is a minimal rendering 
demo, not a drop-in physics extension for another shader pack.

## Source and custom mesh

See [MAINTENANCE.md](MAINTENANCE.md) for the pass order, module map, buffer layout,
shared definitions, and safe editing workflow. The `assets/sphere.obj` file is
included for modeling tools.

From the unpacked pack directory, using Python 3:

```sh
python3 tools/build_sphere.py
python3 tools/obj_to_texture.py assets/your_mesh.obj
```

The first command rebuilds the default sphere; the second replaces it with a
triangulated, closed, outward-wound OBJ. The importer centers and scales the mesh
to unit radius. Shared vertex indices become shared particles. The solver supports
at most 256 vertices and 1024 triangles; the default sphere uses subdivision 2.
The baker updates the textures, generated mesh definitions and texture/buffer
sizes together. Reload the pack afterward.

