# Substance combat prototype — 2026-10-06

Generated using built-in image_gen from the owner's current four-character
concept: water-wave wraith (H2O), cubic salt sentinel (NaCl), iron insect
grappler (Fe2), four-orb carbon trickster (CH4). No API key or paid-provider
workflow. The rejected cute animal assets were not installed.

substance-atlas.png is a 1536x1024 RGBA atlas. Left/middle/right are idle,
attack, hurt. Rows are H2O, NaCl, Fe2, CH4. The source was generated, then
edited with image_gen to remove background/glow and retain alpha. No Python
image edits. Godot AtlasTexture slices the hand-inspected row bounds in
compound_art.gd; nearest-neighbor filtering preserves the pixel style.

Generation prompt: preserve exact four characters from the selected concept;
produce 3 columns x 4 rows with same scale, direction, palette, anchors and
identity. Idle, attack toward right, recoil left. Water lashes fluid arm;
salt extends cubic fist; iron hooks claw; carbon swings hydrogen orbs. Crisp
pixel clusters, no labels, scenery, gradients or animal mascots.
Edit prompt: remove entire colored background and soft glow, output actual
alpha transparency, retain all twelve poses and layout without redesign.

These are three key poses with procedural travel/recoil, not a full hand-drawn
frame animation. Other compounds retain their procedural art with shared
travel/recoil. Battle movement uses an independent overlay to avoid moving
layout containers. Preview uses user://combat_animation_preview.cfg only.
