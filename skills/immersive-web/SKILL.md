---
name: immersive-web
description: Design and engineering principles for highly interactive, spatial and immersive web experiences using purposeful motion, pointer interaction, drag, parallax, depth, sound and physical-feeling digital objects.
---

# Immersive Web

## Purpose

Use this skill when a website should feel like an interactive environment rather than a sequence of static pages.

Immersion must always serve:

- storytelling
- exploration
- navigation
- atmosphere
- physicality
- discovery

Never add interaction only to demonstrate technical complexity.

The experience should reward curiosity without making basic navigation difficult.

---

# 1. CORE PRINCIPLE

The interface is not only something the user sees.

It is something the user manipulates.

Think in terms of:

- objects
- layers
- depth
- surfaces
- movement
- inertia
- focus
- sound
- spatial relationships

Instead of asking:

"What animation should this section have?"

Ask:

"How should this object behave?"

---

# 2. INTERACTION HIERARCHY

Interactions have three levels.

## Level 1 — Feedback

Immediate responses to user input.

Examples:

- hover response
- cursor state
- button depression
- focus change
- object tilt
- subtle sound
- highlight

## Level 2 — Manipulation

The user directly controls something.

Examples:

- drag
- rotate
- scrub
- slide
- inspect
- unfold
- move
- resize

## Level 3 — Discovery

Interaction reveals something unexpected.

Examples:

- hidden content
- alternate navigation
- Easter eggs
- secret articles
- environmental responses
- contextual information

Use Level 3 sparingly.

---

# 3. POINTER-AWARE EXPERIENCES

On pointer devices, elements may respond to cursor position.

Possible behaviors:

- tilt toward pointer
- magnetic attraction
- depth displacement
- lighting response
- perspective change
- subtle translation
- focus shift

Movement should normally be restrained.

Avoid making every element chase the cursor.

Pointer interaction should create physical presence, not visual chaos.

---

# 4. CUSTOM CURSORS

Custom cursors are allowed when they strengthen the experience.

A cursor may:

- change shape
- display action labels
- reveal context
- react to interactive zones
- leave subtle trails
- behave like an object

Possible states:

OPEN

VIEW

PLAY

DRAG

ROTATE

ENTER

NEXT

Custom cursors must never hide what is clickable.

Always preserve:

- keyboard interaction
- touch alternatives
- clear focus states

Do not rely on custom cursors on touch devices.

---

# 5. CURSOR TRAILS

Trails may create:

- ghosting
- persistence
- motion history
- analog display effects

Keep trails:

- short
- lightweight
- subtle

Avoid long decorative trails that obscure content.

Disable or simplify when:

prefers-reduced-motion: reduce

---

# 6. DRAGGABLE OBJECTS

Objects may be draggable when manipulation adds meaning.

Good candidates:

- photographs
- cards
- papers
- magazines
- physical media
- maps
- stickers
- objects inside spatial interfaces

Dragging should include:

- clear affordance
- pointer capture
- inertia when appropriate
- reasonable boundaries
- predictable release behavior

Dragging must not accidentally prevent normal scrolling.

On mobile, carefully separate drag gestures from page scroll.

---

# 7. OBJECT PHYSICS

Digital objects should feel as though they have:

- mass
- friction
- momentum
- resistance
- depth

Motion does not need a full physics engine.

Often this can be communicated through:

- easing
- inertia
- spring behavior
- delayed following
- subtle rotation

Different objects may have different perceived weight.

Paper ≠ glass ≠ metal.

---

# 8. MAGNETIC INTERACTION

Important controls may subtly attract the pointer.

Use for:

- navigation
- major CTAs
- media controls
- interactive objects

Keep displacement small.

The user should feel attraction rather than fight against it.

---

# 9. PARALLAX

Parallax should communicate depth.

Think in layers:

foreground

midground

background

environment

Different layers move at different speeds.

Do not apply parallax to every element.

Avoid excessive scroll-jacking.

Content must remain readable during motion.

---

# 10. SCROLL AS CAMERA

For highly immersive sections, scrolling may behave like camera movement.

Examples:

- moving through an archive
- approaching an object
- entering a photograph
- moving between spatial layers
- revealing physical media

Scroll-driven sequences must remain controllable.

Never trap the user in unnecessarily long animation sequences.

---

# 11. DEPTH

Create depth using combinations of:

- scale
- blur
- opacity
- perspective
- shadows
- overlap
- lighting
- parallax
- focus

Do not depend only on large `z-index` values.

The composition should visually communicate what is near and far.

---

# 12. FOCUS

Focus can guide storytelling.

Possible technique:

background blurred
→ selected object sharp

or:

environment darkened
→ active object illuminated

Focus transitions should help the user understand what currently matters.

---

# 13. PHYSICAL UI

When appropriate, replace abstract UI with meaningful physical metaphors.

Instead of:

generic audio widget

consider:

music player

Instead of:

generic gallery card

consider:

photographic print

Instead of:

generic menu

consider:

archive index

Instead of:

generic carousel

consider:

stack of media

Do not force physical metaphors when a conventional control would be clearer.

---

# 14. LAYERED INTERFACES

Allow objects to overlap.

Possible layers:

background environment

large typography

photography

physical objects

metadata

navigation

cursor layer

ambient effects

Overlap should be art-directed.

Never allow important content to become unreadable accidentally.

---

# 15. REVEAL INTERACTIONS

Content can be discovered through:

- hover
- drag
- click
- rotation
- unfolding
- moving another object
- scrolling
- focus
- audio interaction

Reveals should be learnable.

After one or two interactions, users should understand the visual language.

---

# 16. EASTER EGGS

Easter eggs may reward exploration.

Examples:

- hidden media
- secret page
- alternate visual state
- unexpected object behavior
- hidden message
- environmental event

Rules:

Easter eggs must never contain essential navigation.

They must not interrupt the user.

They should fit the world of the experience.

---

# 17. AMBIENT MOTION

Not every animation needs user input.

Ambient movement can make environments feel alive.

Examples:

- slow rotation
- subtle floating
- lighting movement
- environmental grain
- screen flicker
- background motion

Ambient movement should be slow and subtle.

Too much ambient movement creates visual fatigue.

---

# 18. SOUND INTERACTION

Sound can strengthen physicality.

Possible feedback:

- mechanical click
- camera shutter
- paper movement
- electronic beep
- object impact
- media mechanism

Rules:

- keep effects short
- maintain low perceived volume
- avoid repeated annoying sounds
- provide mute controls
- respect user expectations

Do not autoplay loud sound.

---

# 19. PAGE TRANSITIONS

Transitions may reinforce spatial continuity.

Examples:

object expands into page

photograph becomes article hero

album cover opens into music page

paper unfolds into editorial

Avoid transitions that exist only as loading decoration.

Transitions should explain:

"Where did I come from?"

and

"Where am I going?"

---

# 20. MOTION SYSTEM

Create a consistent motion vocabulary.

Define:

FAST
100–250ms

STANDARD
250–500ms

SLOW
500–1200ms

AMBIENT
continuous / multi-second

These are conceptual ranges, not rigid requirements.

Use consistent easing families.

Avoid arbitrary easing on every component.

---

# 21. PERFORMANCE

Immersion must remain performant.

Prefer:

transform
opacity

Be cautious with:

filter
backdrop-filter
large blur
multiple shadows
continuous canvas rendering
large WebGL scenes

Use:

requestAnimationFrame

only when needed.

Pause continuous effects when:

- tab is hidden
- object is offscreen
- interaction is inactive

Use IntersectionObserver where appropriate.

---

# 22. DEVICE CAPABILITY

Do not assume every device can run the maximum experience.

Create progressive enhancement.

HIGH CAPABILITY

- full effects
- WebGL
- pointer reactions
- complex depth

MEDIUM

- simplified effects
- reduced parallax
- optimized scenes

LOW / MOBILE

- static alternatives
- lighter motion
- fewer simultaneous effects

The visual identity must survive every tier.

---

# 23. MOBILE

Mobile is not desktop without a mouse.

Replace hover interactions with:

- tap
- press
- swipe
- controlled drag

Remove custom cursor logic.

Reduce:

- excessive parallax
- tiny interactive targets
- complex 3D
- scroll conflicts

Preserve the immersive storytelling.

---

# 24. REDUCED MOTION

Always respect:

prefers-reduced-motion: reduce

Possible adaptations:

- disable cursor trails
- remove large parallax
- stop continuous rotation
- replace animated transitions with fades
- remove camera-like movement

Do not remove content.

Only reduce motion.

---

# 25. ACCESSIBILITY

Experimental interaction must remain accessible.

Ensure:

- semantic controls
- keyboard support
- visible focus
- descriptive labels
- usable contrast
- touch-friendly targets
- logical reading order

If an object can be clicked with a pointer, it should generally be reachable with keyboard interaction as well.

---

# 26. INTERACTION DENSITY

Do not make everything interactive.

The contrast between:

STATIC

and

INTERACTIVE

creates meaning.

Important interactive objects should feel special.

Too many interactive elements destroy hierarchy.

---

# 27. IMMERSION CHECK

Before adding an effect ask:

Does this:

1. communicate information?
2. strengthen atmosphere?
3. improve navigation?
4. create meaningful physicality?
5. reward exploration?

If the answer is NO to all five:

do not add it.

---

# 28. ANTI-PATTERNS

Avoid:

- animation everywhere
- scroll hijacking
- mystery navigation
- excessive cursor effects
- infinite loaders
- unnecessary splash screens
- decorative WebGL without purpose
- motion that delays content
- inaccessible drag-only navigation
- interactions that only work with hover
- constant camera movement
- fake complexity

Immersion is not the same as complexity.

---

# 29. REVIEW CHECKLIST

Before considering an immersive experience complete:

[ ] Is primary navigation obvious?

[ ] Are interactions purposeful?

[ ] Does the pointer provide useful feedback?

[ ] Do draggable objects behave predictably?

[ ] Is depth understandable?

[ ] Are animations consistent?

[ ] Does sound have controls?

[ ] Does keyboard navigation work?

[ ] Does touch have equivalent interactions?

[ ] Is reduced motion supported?

[ ] Is performance acceptable?

[ ] Are expensive effects paused when unnecessary?

[ ] Can users still access all important content without discovering Easter eggs?

---

# FINAL PRINCIPLE

A great immersive website should make the user curious enough to interact without forcing them to learn how the website works.

Make the digital world feel physical.

Make interaction meaningful.

Reward exploration.