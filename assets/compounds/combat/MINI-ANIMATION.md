# Mini sprite attack/hurt pass — 2026-10-06

mini-substance-atlas-v1.png replaces the older detailed four-character atlas
in the runtime. Built-in image_gen, with approved mini-shaded-v1/02-core-and-acids
as design reference. 1280x1280 RGBA, four equal rows and columns, 320px cells.
Rows: H2O, NaCl, Fe2, CH4. Columns: idle, windup, impact, hurt.
Existing detailed atlas is preserved as a prior version.

Prompt: preserve exact miniature silhouettes/palettes, two-dot faces, one shadow
and highlight, low-detail pixel clusters, no textures/accessories. Produce fixed
4x4 transparent atlas with shared scale/anchors, no labels or scenery. Water
compresses then extends a short wave arm; salt crouches then thrusts a cube;
iron lowers then thrusts its front lobe; carbon contracts then extends two nodes.
Hurt poses squash/tilt/recoil with at most one chip or attached water bead.

Runtime uses nearest filtering and square frames. Attack overlay now advances
windup -> impact -> idle with its own age, respecting pause and live 2x changes.
Hurt remains linked to actual received damage. Four key poses, not a full
multi-frame hand-animated sequence. Other 22 mini designs are concept sheets
only and have not yet received bespoke animation atlases.

Validation: scene checks; 17 windowed combat motion assertions; 29 windowed
battle-feedback assertions. Inspected real attack/hurt screenshots at game size.
Run-Attack-Preview.cmd uses a separate preview save.
