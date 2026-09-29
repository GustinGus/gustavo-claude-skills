---
name: web-3d
description: Design, engineering, interaction and performance guidelines for purposeful 3D experiences on the web using Three.js, React Three Fiber, GLTF/GLB assets, physically based materials, lighting, pointer interaction and progressive enhancement.
---

# Web 3D

## Purpose

Use this skill when 3D objects or environments are part of a web experience.

3D must serve:

- storytelling
- navigation
- product or object inspection
- atmosphere
- spatial composition
- interaction

Never use 3D only because it looks technically impressive.

The best web 3D feels integrated with the interface.

---

# 1. CORE PRINCIPLE

Treat 3D objects as interface elements.

Every object should answer:

Why is this object here?

What happens when the user interacts with it?

What information or navigation does it provide?

If an object has no purpose, reconsider adding it.

---

# 2. TECHNOLOGY CHOICE

For React projects, prefer:

- Three.js
- React Three Fiber
- @react-three/drei

Use raw Three.js when direct control or a non-React architecture makes more sense.

Do not add a 3D framework when CSS transforms or a video can achieve the same result more efficiently.

---

# 3. ASSET FORMAT

Prefer:

GLB / GLTF

Avoid shipping development formats such as:

- OBJ + multiple loose textures
- FBX
- Blender source files

to the production client unless specifically required.

GLB is generally preferred for compact delivery.

---

# 4. MODEL PREPARATION

Before using a model:

- remove hidden geometry
- remove unused materials
- remove unused textures
- reduce unnecessary polygons
- merge meshes when appropriate
- preserve separate meshes when interaction requires them
- verify normals
- verify UVs
- verify pivot/origin
- verify scale
- verify orientation

Objects intended to rotate should have sensible origins.

---

# 5. GEOMETRY

Use the lowest complexity that preserves the intended silhouette.

Do not use cinematic-production geometry directly on a website without optimization.

Prioritize detail where it affects:

- silhouette
- reflections
- close-up inspection

Small invisible details do not need thousands of polygons.

---

# 6. TEXTURES

Use textures intentionally.

Prefer modern compressed texture workflows when supported.

Consider:

- KTX2
- Basis compression
- WebP / AVIF for supporting image assets

Avoid unnecessary 4K or 8K textures.

Typical web objects often work with:

512px
1024px
2048px

depending on screen coverage and inspection distance.

Do not choose resolution based only on source availability.

---

# 7. PBR MATERIALS

Prefer physically based materials when realism matters.

Common properties:

- base color
- roughness
- metalness
- normal
- transmission
- opacity
- emissive

Materials should represent believable physical surfaces.

Examples:

metal → high metalness

paper → high roughness

glass → transmission / refraction behavior

plastic → low-to-medium roughness

Do not make every object glossy.

---

# 8. TRANSLUCENT PLASTIC

For translucent electronics or objects:

Consider:

- transmission
- thickness
- roughness
- index of refraction
- subtle tint
- internal geometry

Transparent materials look more convincing when there is something visible inside them.

Avoid making translucent plastic behave like perfect crystal glass.

---

# 9. GLASS

Glass should react to its environment.

Consider:

- transmission
- refraction
- roughness
- thickness
- environment lighting

Frosted glass should use controlled roughness rather than excessive CSS-like blur.

Be cautious with expensive real-time refraction.

---

# 10. METAL

Metal requires meaningful reflections.

Use:

- environment maps
- HDRI
- controlled studio lights

Brushed metal should not look like a perfect mirror.

Surface roughness is essential.

---

# 11. IRIDESCENCE

For CDs and similar materials, subtle iridescence may be appropriate.

The effect should change with:

- viewing angle
- lighting
- surface orientation

Avoid rainbow effects that overpower the physical object.

The base object should still read as a CD.

---

# 12. LIGHTING

Start simple.

A strong scene may need only:

- environment light
- key light
- fill light
- subtle rim light

Do not add many lights without purpose.

Every dynamic light has a cost.

Lighting should reveal:

- shape
- material
- depth
- interaction

---

# 13. ENVIRONMENT MAPS

Environment maps are useful for:

- metal
- glass
- polished plastic
- CDs
- reflective electronics

Choose an environment that matches the visual world.

Do not use a random studio HDRI if its reflections contradict the scene.

---

# 14. SHADOWS

Use shadows to anchor objects.

Prefer limited, intentional shadows.

Possible alternatives:

- baked shadows
- contact shadows
- blob shadows
- ambient occlusion

Do not enable expensive dynamic shadows on every object automatically.

---

# 15. CAMERA

The camera is part of the interface.

Choose perspective intentionally.

Avoid excessive wide-angle distortion unless it supports the concept.

Common camera behaviors:

- fixed composition
- subtle pointer response
- scroll-controlled movement
- object inspection
- cinematic transition

The user should not lose orientation.

---

# 16. CAMERA MOTION

Camera movement should be restrained.

Good uses:

- approaching an object
- moving between environments
- transitioning into content
- subtle depth response

Avoid:

- constant floating camera
- unnecessary orbiting
- aggressive zooming
- motion that causes discomfort

---

# 17. OBJECT ROTATION

Objects may rotate continuously when appropriate.

For ambient 360-degree rotation:

- keep speed slow
- maintain readable orientation
- pause when offscreen
- pause when tab is hidden
- reduce or stop for reduced-motion users

When the user interacts with the object, manual control may temporarily override ambient rotation.

---

# 18. POINTER RESPONSE

3D objects may respond to pointer position.

Possible behaviors:

- tilt
- rotate
- move
- focus
- highlight
- lighting response

Map pointer movement to small ranges.

Avoid one-to-one exaggerated rotation.

Use smoothing or interpolation.

The object should feel weighted.

---

# 19. DRAG TO ROTATE

When inspection matters, allow drag rotation.

Recommended behavior:

pointer down
→ capture interaction

pointer move
→ rotate object

pointer up
→ release

Optional:

→ continue with subtle inertia

Prevent accidental text selection.

Do not break page scrolling on mobile.

---

# 20. HOVER

Hover may:

- slow rotation
- stop rotation
- reveal metadata
- change lighting
- move object forward
- change cursor
- highlight interactive components

Hover should indicate interactivity.

Do not create dramatic motion for every hover event.

---

# 21. CLICK / TAP

Clicking a 3D object may:

- navigate
- open information
- activate media
- focus the camera
- expand the object
- trigger a transition

Clickable meshes should have meaningful hit areas.

Tiny geometry should not be required for basic navigation.

---

# 22. HTML + 3D

3D does not need to contain all interface text.

Prefer HTML for:

- paragraphs
- navigation
- accessibility
- metadata
- article content

Use 3D for:

- physical objects
- environments
- spatial effects
- meaningful visual interactions

Combine both layers intentionally.

---

# 23. DOM SYNCHRONIZATION

When HTML and WebGL elements must align:

- use shared normalized coordinates
- measure carefully
- avoid excessive layout reads
- update only when necessary

React Three Fiber / Drei helpers may be used where appropriate.

Do not continuously recalculate DOM geometry without need.

---

# 24. SCROLL + 3D

Scroll may control:

- object rotation
- camera position
- object position
- scene transitions
- depth

Keep scroll behavior reversible and predictable.

Users should remain in control.

Do not hijack wheel input unnecessarily.

---

# 25. LOADING

3D assets should not leave the user staring at a blank screen.

Use:

- progressive loading
- useful loading feedback
- lightweight placeholders
- poster images
- skeleton states where appropriate

Do not create fake long loading sequences.

If the experience can begin before every model loads, let it begin.

---

# 26. LAZY LOADING

Do not load every 3D asset immediately.

Load based on:

- route
- viewport proximity
- user intent
- section activation

Large secondary scenes should load only when needed.

---

# 27. CODE SPLITTING

Keep 3D code out of pages that do not need it.

Use route or component-level splitting where appropriate.

Do not force the Three.js runtime into every page merely because the homepage uses 3D.

---

# 28. RENDER LOOP

Continuous rendering is expensive.

When possible, consider rendering on demand.

Pause or reduce rendering when:

- scene is static
- page is hidden
- scene is offscreen
- device is constrained

In React Three Fiber, choose frameloop behavior intentionally.

---

# 29. DEVICE PIXEL RATIO

Do not blindly render at maximum device pixel ratio.

High-DPI screens can multiply GPU cost dramatically.

Use controlled DPR ranges when appropriate.

Visual sharpness should be balanced with performance.

---

# 30. POST-PROCESSING

Use post-processing sparingly.

Possible effects:

- bloom
- grain
- vignette
- depth of field
- chromatic aberration

Every effect must have visual purpose.

Avoid stacking many full-screen passes.

Subtle effects usually work better.

---

# 31. SHADERS

Custom shaders may be used for:

- iridescence
- distortion
- analog display effects
- procedural materials
- environmental transitions

Do not use custom shaders when standard materials solve the problem.

Shaders must degrade gracefully.

---

# 32. PERFORMANCE BUDGET

Treat performance as a design constraint.

Monitor:

- model size
- texture memory
- draw calls
- triangles
- shader complexity
- active lights
- post-processing
- render resolution
- frame time

Do not optimize only after the entire experience is built.

---

# 33. TARGET EXPERIENCE

Aim for smooth interaction on realistic consumer hardware.

A beautiful scene that stutters is not successful.

Prioritize:

interaction stability

over

maximum visual complexity.

---

# 34. MOBILE STRATEGY

Mobile does not need the exact desktop scene.

Possible adaptations:

- fewer objects
- lower texture resolution
- simplified materials
- no expensive refraction
- reduced post-processing
- lower DPR
- static environment
- pre-rendered alternatives

Preserve the art direction.

Reduce technical complexity.

---

# 35. TOUCH

Touch interactions require different assumptions.

Use:

- tap
- drag
- swipe

Do not depend on hover.

Avoid gestures that fight native page scrolling.

If horizontal object rotation is used, preserve vertical page movement.

---

# 36. FALLBACK

Every critical 3D interaction should have a fallback.

Possible fallback:

3D object
→ rendered image

interactive model
→ image + conventional button

WebGL scene
→ art-directed static composition

The site should still communicate its identity without WebGL.

---

# 37. REDUCED MOTION

Respect:

prefers-reduced-motion: reduce

Adapt:

- continuous rotation
- camera movement
- floating
- scroll-linked transformations
- inertia

The object may remain visible and interactive without ambient motion.

---

# 38. ACCESSIBILITY

WebGL itself is not sufficient semantic UI.

Provide accessible HTML equivalents for:

- navigation
- labels
- actions
- media controls

If clicking a 3D object performs navigation, provide an accessible DOM control representing the same action.

---

# 39. MEMORY MANAGEMENT

Dispose resources when they are no longer needed.

Consider:

- geometries
- materials
- textures
- render targets
- event listeners

Route transitions should not accumulate abandoned GPU resources.

---

# 40. DEVELOPMENT WORKFLOW

Recommended workflow:

1. establish visual goal
2. prototype with primitives
3. validate interaction
4. import optimized model
5. establish materials
6. establish lighting
7. implement interaction
8. profile performance
9. implement mobile tier
10. implement accessibility fallback
11. polish

Do not begin with expensive final assets.

---

# 41. DEBUGGING

During development, inspect:

- FPS
- frame time
- draw calls
- triangle count
- texture memory
- scene graph
- loading size

Remove debugging tools from production when unnecessary.

---

# 42. ANTI-PATTERNS

Avoid:

- giant unoptimized GLB files
- unnecessary 4K textures
- 60 FPS rendering of static scenes
- dozens of dynamic lights
- shadows on everything
- WebGL text for normal paragraphs
- 3D navigation without accessible alternatives
- heavy post-processing stacks
- complex physics for simple movement
- loading every model on first paint
- desktop scene copied unchanged to mobile
- decorative 3D with no narrative purpose

---

# 43. REVIEW CHECKLIST

Before approving a 3D experience:

[ ] Does every major 3D object have a purpose?

[ ] Are models optimized?

[ ] Are textures appropriately sized?

[ ] Are materials physically coherent?

[ ] Is lighting intentional?

[ ] Is interaction understandable?

[ ] Can pointer users manipulate objects comfortably?

[ ] Does touch work?

[ ] Does keyboard-accessible HTML provide equivalent actions?

[ ] Is reduced motion supported?

[ ] Are offscreen scenes paused or unloaded?

[ ] Is rendering resolution controlled?

[ ] Is mobile simplified where necessary?

[ ] Is loading reasonable?

[ ] Are GPU resources cleaned up?

[ ] Does the page still work if WebGL fails?

---

# FINAL PRINCIPLE

3D on the web is not a visual trophy.

It is another interface material.

Use it like typography, photography, sound and motion:

with purpose.

The user should remember the object and the experience,

not the fact that Three.js was used.