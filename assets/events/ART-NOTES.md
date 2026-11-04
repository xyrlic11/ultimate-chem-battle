# Pixel event illustrations

Built-in imagegen; 2026-10-06. Owner requested pixel art and lower detail. Replaces initial smooth cartoons. Both event image surfaces use nearest-neighbor filtering.

## Exact generation prompt

Use case: illustration-story. Asset type: Ultimate Chem Battle event scene. Generate a simple genuine low-resolution pixel art scene, as if drawn on a 192x128 pixel canvas then enlarged with nearest-neighbor. Large visible square pixel clusters, crisp stair-step edges, limited 24-color palette, two-tone shadows, very sparse detail, no antialiasing, no smooth outlines, no painting, no fine texture. Woodland background in muted teal and earthy colors, recognizable subject occupying central 65 percent, landscape 3:2; playful adventure atmosphere but only mildly cute, normal eyes. No text, UI, borders or watermark. Subject: 

Append one subject per asset:

- mushrooms.png: A small cluster of pale mint glowing mushrooms visibly releasing little wisps of mist on the forest floor.
- deer.png: One slender translucent blue glass deer with modest antlers, looking back beside a forest path. Clearly recognizable deer, not a mascot.
- wanderer.png: A hooded travelling alchemist sitting by a small campfire, with a satchel and two glass bottles. Face simple, modest proportions.
- cache.png: A worn wooden treasure chest with two compartments, a few coins and one little glowing blue crystal, faint vapor around it, beside a forest path. Chest is closed enough to leave its contents uncertain.
- hollow.png: An old tree trunk with a clearly visible dark hollow opening at its base beside a trail.
- red_button.png: An unmistakable large red push button on a weathered stone pedestal, partly wrapped in vines; tiny puffs of vapor at the base.
- rock.png: One unusual grey mineral rock with a simple pale crystalline vein, resting beside fallen leaves on a forest path.
- lab.png: A small abandoned outdoor alchemy workbench with glass flasks, a book, metal pipes and one glowing vessel. Readable simple shapes.
- monster.png: A compact jagged purple mineral creature, small narrowed eyes, guarding a wooden bridge over a creek. Creature is visibly an obstacle but not frightening.

Related encounters reuse matching scenes: deer trail/deer, roots/vault/cache, merchant/trainer/rescue/funding/camp/wanderer, ruins/researcher/reactor/distiller/lab. Same illustration appears on route and narrative, depicting clues rather than outcomes. No extra API or CLI used.


## Interaction variants (2026-10-06)

Built-in imagegen edits use the named base image as the edit target (departure is a new scene).
Exact shared prompt:

Use case: style-transfer. Game event illustration. Preserve the simple chunky LOW-DETAIL pixel art style, square pixel clusters, limited muted colors, crisp edges, two-tone shadows and restrained charm. Landscape 3:2 composition, central readable subject. No smooth illustration, fine detail, letters, text, UI, borders, watermark or reward numbers. Change the visible action/state, keeping character and location identity: 

- mushrooms_sample.png (base mushrooms): Show the mushrooms after interaction: a gloved hand has collected a small mushroom sample into an open glass vial in foreground, with a little mist escaping. Keep mushrooms and woodland recognizable.
- deer_feed.png (base deer): Show this same glass deer bending down and eating a small pile of food that the traveller has placed on the ground. Keep the woodland location.
- wanderer_deal.png (base wanderer): Show the same hooded alchemist by his campfire with his satchel now open in front of him, offering a small bottle towards the viewer. The open satchel is clearly visible.
- cache_open.png (base cache): Show the same chest now OPEN, its lid raised, a few coins and blue mineral visible inside; disturbed roots around it. Keep the woodland.
- hollow_inside.png (base hollow): Show a close view looking INSIDE this tree hollow: empty dry wooden floor, roots and a little daylight at the entrance. No treasure or creature.
- rock_touch.png (base rock): Show this same grey rock at close range beside a gloved hand reaching toward it and the toe of a boot; no broken rock or treasure.
- lab_active.png (base lab): Show this same alchemy workbench actively bubbling after interaction: one flask emitting a small turquoise vapor cloud, open notes and a gloved hand adjusting a valve.
- red_button_pressed.png (base red_button): Show this same red button depressed by a gloved finger, with yellow-green toxic vapor suddenly billowing from the base of the pedestal. Keep the red button clearly recognizable.
- monster_alert.png (base monster): Show this same purple mineral creature on the bridge leaning forward into a defensive ready-to-fight stance, braced arms, eyes narrowed, dust under its claws.
- departure.png (base none): A quiet woodland path seen from a departing traveller, a small bootprint trail leading away, trees and roots framing a clear path. No person, treasure or monster.

Narrative artwork is derived from saved event ID and choice. Related interactions share scene variants; departures use a shared forest path. Combat retains the triggering interaction scene. Opening/route clues keep the original image.
