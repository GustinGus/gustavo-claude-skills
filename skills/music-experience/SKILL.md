---
name: music-experience
description: Design and engineering guidelines for music-centered web experiences using persistent playback, albums as interactive objects, editorial playlists, physical-media metaphors, accessible audio controls and immersive audiovisual interaction.
---

# Music Experience

## Purpose

Use this skill when music is a meaningful part of a digital experience rather than background decoration.

Music may influence:

- navigation
- storytelling
- visual identity
- interaction
- atmosphere
- editorial structure
- physical objects
- page transitions

The objective is to make music feel integrated with the experience.

Not embedded as an afterthought.

---

# 1. CORE PRINCIPLE

Do not think only in terms of:

audio player

Think in terms of:

listening experience

The interface surrounding music should communicate:

- artist
- album
- track
- year
- context
- artwork
- physical medium
- listening state

Music should feel culturally present.

---

# 2. MUSIC AS CONTENT

When music is editorially important, it may structure the website itself.

Possible structures:

- artists
- albums
- tracks
- scenes
- genres
- years
- cities
- playlists
- labels
- movements

Do not reduce music content to a generic Spotify-like list.

The presentation should follow the art direction of the project.

---

# 3. NOW PLAYING

A global NOW PLAYING state may include:

- track
- artist
- album
- artwork
- current time
- duration
- playback state

Example:

NOW PLAYING

03
TEARDROP

MASSIVE ATTACK
MEZZANINE / 1998

01:42 ━━━━━━━━━━ 05:30

The component may be compact by default and expandable on interaction.

---

# 4. PERSISTENT PLAYBACK

When technically appropriate, audio should continue while the user navigates through internal content.

Avoid restarting the track unnecessarily.

For SPA / client-side navigation:

keep audio state above route-level content.

Preserve:

- active track
- playback position
- volume
- mute state
- queue when appropriate

Navigation should not feel like ejecting the record every time a page changes.

---

# 5. USER-INITIATED AUDIO

Do not unexpectedly start loud music.

Audio should normally begin after a clear user interaction.

Examples:

ENTER + ENABLE SOUND

PLAY

LISTEN

START EXPERIENCE

Respect browser autoplay restrictions.

Never attempt deceptive autoplay workarounds.

---

# 6. SOUND ENTRY

If sound is central to the experience, the entrance may present a choice.

Example:

ENTER WITH SOUND

ENTER MUTED

Do not block access to the website simply because the user does not want audio.

The muted experience must remain complete.

---

# 7. AUDIO CONTROLS

Always provide understandable controls for:

- play
- pause
- mute
- volume when appropriate
- previous
- next
- progress
- close/minimize when appropriate

Do not hide basic controls behind obscure interactions.

A physical metaphor may surround the controls, but usability remains mandatory.

---

# 8. PHYSICAL MEDIA

Music interfaces may reference physical formats.

Examples:

- vinyl
- cassette
- CD
- MiniDisc
- portable CD player
- MiniDisc player
- stereo
- headphones
- album booklet

Choose formats that make cultural and historical sense for the project.

Physical media may function as:

- navigation
- player
- artwork
- archive object
- transition element

---

# 9. ALBUM AS OBJECT

An album should not automatically become a rectangular card.

It may behave like:

CD case

record sleeve

MiniDisc

booklet

physical package

Possible interactions:

hover
→ metadata

drag
→ inspect

click
→ open album

play
→ activate music

rotate
→ inspect object

The interaction should reinforce the physical medium.

---

# 10. PLAYBACK VISUAL STATE

Physical objects may respond to playback.

Examples:

CD rotates

cassette reels move

MiniDisc mechanism activates

display illuminates

equalizer becomes active

Keep motion subtle.

Do not create distracting animations that compete with reading.

---

# 11. MUSIC PLAYER AS OBJECT

When the art direction supports it, the player may resemble a physical device.

Possible inspirations:

- portable CD player
- MiniDisc player
- stereo component
- compact electronic device

The player should still expose familiar controls.

Aesthetic authenticity must not destroy usability.

---

# 12. PLAYER STATES

Define explicit states.

Examples:

IDLE

LOADING

PLAYING

PAUSED

BUFFERING

ERROR

ENDED

MUTED

The interface should communicate these states clearly.

Never leave the user wondering whether playback failed.

---

# 13. LOADING AUDIO

Audio may take time to load.

Provide subtle feedback.

Avoid fake loading percentages.

If a track cannot play:

- show an understandable error
- preserve the rest of the interface
- allow retry where appropriate

---

# 14. PROGRESS

Users should understand track progress.

Possible visual forms:

- linear timeline
- LCD indicator
- radial disc progress
- physical-device display

Progress should remain seekable when seeking is supported.

Do not sacrifice usability for novelty.

---

# 15. SCRUBBING

If the user can seek:

- make the hit area comfortable
- update time feedback
- support pointer and touch
- preserve keyboard accessibility

Visual complexity should not make scrubbing difficult.

---

# 16. PLAYLISTS

Playlists may be editorial objects.

They can communicate:

- era
- mood
- scene
- city
- cultural context
- article theme

Examples:

AFTER MIDNIGHT

UNDERGROUND

LONDON 1998

SUNDAY MORNING

TRANSIT

Do not create arbitrary playlist names without editorial purpose.

---

# 17. PLAYLIST PRESENTATION

A playlist does not need to resemble a streaming service.

Possible formats:

- handwritten track list
- CD booklet
- magazine column
- archive sheet
- MiniDisc index
- printed insert

Maintain clear track ordering and playback controls.

---

# 18. TRACK METADATA

Useful metadata may include:

- title
- artist
- album
- year
- track number
- duration
- label
- genre
- city or scene when editorially relevant

Do not invent metadata.

Historical information must be sourced.

---

# 19. ALBUM ARTWORK

Artwork is editorial content.

Preserve:

- aspect ratio
- visual integrity
- artist credit when required
- source/license records

Do not casually crop iconic artwork when the full composition matters.

---

# 20. MUSIC + ARTICLES

Music may accompany editorial stories.

Possible relationships:

artist article
→ relevant album

fashion article
→ period playlist

cultural timeline
→ tracks from that era

photography essay
→ curated soundscape

Make the relationship explicit.

Do not imply historical connections that are only editorial choices.

---

# 21. MUSIC + SCROLL

Scroll may influence visual presentation of music.

Examples:

album comes into focus

disc rotates into view

track metadata changes

visual environment shifts

Avoid tying actual playback position to page scrolling unless the concept specifically requires it.

Users should remain in control of audio.

---

# 22. MUSIC + 3D

3D music objects may include:

- CD
- MiniDisc
- headphones
- player
- speaker
- cassette

Possible playback response:

rotation

mechanism movement

display state

lighting

Do not create heavy 3D scenes only to show a play button.

Use 3D when physicality adds meaning.

---

# 23. MUSIC + CURSOR

Cursor states may reflect music actions.

Examples:

PLAY

PAUSE

LISTEN

OPEN ALBUM

DRAG

Do not rely solely on cursor labels.

The underlying interface must remain understandable.

---

# 24. AUDIOVISUAL RESPONSE

Visuals may react subtly to audio.

Possible inputs:

- amplitude
- frequency bands
- beat energy

Possible outputs:

- light intensity
- subtle scale
- shader response
- grain
- environmental movement

Avoid generic equalizer visualizations unless they fit the concept.

Audio-reactive visuals should support atmosphere.

---

# 25. WEB AUDIO

Use the Web Audio API when advanced audio processing is genuinely needed.

Possible uses:

- analysis
- filtering
- spatial audio
- crossfades
- reactive visuals

Do not introduce Web Audio complexity for basic playback that an HTML audio element can handle well.

---

# 26. CROSSFADES

Crossfades may improve transitions between curated tracks.

Keep them controlled.

Do not alter recordings aggressively.

Allow tracks to preserve their intended beginnings and endings when editorial authenticity matters.

---

# 27. VOLUME

Use sensible initial volume.

Do not start at unexpectedly high levels.

Remember volume preferences during the session when appropriate.

A mute control should always be easy to find when sound is active.

---

# 28. UI SOUND VS MUSIC

Separate:

MUSIC

from

INTERFACE SOUND.

Muting interface effects should not necessarily require stopping music.

When appropriate, provide separate controls.

Example:

MUSIC ON/OFF

UI SOUND ON/OFF

Avoid excessive settings when the experience is simple.

---

# 29. INTERFACE SOUNDS

Possible sounds:

- mechanical click
- CD tray
- MiniDisc mechanism
- cassette button
- camera shutter
- subtle electronic beep

Keep effects:

short

quiet

purposeful

Do not play sound for every hover.

---

# 30. BACKGROUND AMBIENCE

Environmental audio may include:

- station ambience
- room tone
- street noise
- club ambience
- transportation sounds

Use sparingly.

Ambience must not compete with music or spoken content.

Provide control over it.

---

# 31. ROUTE TRANSITIONS

Music should not glitch during navigation.

Avoid:

- duplicated playback
- restarting tracks
- overlapping players
- losing playback state
- sudden volume jumps

Test transitions repeatedly.

---

# 32. STATE ARCHITECTURE

Keep playback state centralized.

Possible state:

currentTrack

isPlaying

currentTime

duration

volume

isMuted

queue

activePlaylist

Avoid duplicating playback state across unrelated components.

The audio engine should have a single clear owner.

---

# 33. MEDIA SESSION

When appropriate, integrate the Media Session API.

Provide:

- title
- artist
- album
- artwork

Support system media controls where available.

This improves playback outside the active browser view.

---

# 34. KEYBOARD

Support useful keyboard interaction.

Examples:

Space
→ play / pause when focus context permits

Arrow keys
→ seek when progress control is focused

Standard controls should remain accessible through Tab navigation.

Do not hijack global keyboard shortcuts unnecessarily.

---

# 35. SCREEN READERS

Controls need meaningful labels.

Examples:

Play Teardrop by Massive Attack

Pause

Next track

Mute music

Seek track

Do not expose controls only as unlabeled icons.

---

# 36. MOTION

Music-related motion must respect:

prefers-reduced-motion

When reduced:

CD rotation
→ stop

equalizer
→ static

audio-reactive movement
→ disabled or minimized

Music itself does not need to stop because reduced motion is enabled.

---

# 37. MOBILE

Mobile music controls should be easy to reach.

Consider:

compact bottom player

expandable player

large touch targets

Avoid covering important content.

Do not depend on hover.

Heavy 3D player representations may be simplified.

---

# 38. INTERRUPTION

Consider real-world interruption.

Examples:

phone call

Bluetooth change

tab suspension

device lock

audio focus change

The interface should recover gracefully when playback is interrupted.

---

# 39. PERFORMANCE

Audio should not make the site unnecessarily heavy.

Do not preload an entire music library.

Load tracks based on:

- user selection
- current playlist
- likely next track

Use appropriate audio formats and bitrate.

Do not sacrifice reasonable quality, but avoid oversized source files when unnecessary.

---

# 40. BANDWIDTH

Respect constrained connections.

Do not automatically download large audio files simply because they appear in the archive.

Metadata and artwork may load before audio.

Playback can begin on demand.

---

# 41. COPYRIGHT AND LICENSING

Do not assume a song may be hosted or streamed because it can be found online.

For production:

- verify music rights
- verify streaming/embedding permissions
- use authorized providers where appropriate
- maintain licensing information

Do not download or redistribute copyrighted recordings without permission.

During prototypes, clearly distinguish placeholders from licensed production audio.

---

# 42. EXTERNAL MUSIC SERVICES

When using authorized external services:

- respect their terms
- use official embeds or APIs where appropriate
- preserve attribution
- do not fake playback availability

The visual experience may surround an official player while respecting provider restrictions.

---

# 43. HISTORICAL INTEGRITY

Never invent:

- artist quotes
- album dates
- track credits
- genre relationships
- artist influences
- scene membership
- chart information

Distinguish:

documented historical relationship

from

editorial playlist association.

Example:

"This track fits the atmosphere of this editorial."

is different from:

"This track influenced this movement."

Do not confuse them.

---

# 44. FALLBACK

The site must remain usable if audio cannot play.

If audio fails:

- preserve article content
- preserve navigation
- show clear playback status
- allow retry

Music may enrich the experience without becoming a single point of failure.

---

# 45. MUSIC EXPERIENCE REVIEW

Before approving:

[ ] Is music meaningfully integrated?

[ ] Is playback user-initiated?

[ ] Is mute easy to find?

[ ] Does playback survive internal navigation when intended?

[ ] Are track states clear?

[ ] Is seeking usable?

[ ] Does mobile work?

[ ] Are keyboard controls accessible?

[ ] Do controls have semantic labels?

[ ] Does reduced motion affect visuals appropriately?

[ ] Are audio files loaded efficiently?

[ ] Are interface sounds restrained?

[ ] Are metadata and historical claims accurate?

[ ] Are licensing requirements documented?

[ ] Does the site remain usable without audio?

---

# FINAL PRINCIPLE

Do not attach music to the website.

Build music into the experience.

The player is an interface.

The album is an object.

The playlist is editorial.

The sound is part of the world.

But the user always controls whether they listen.