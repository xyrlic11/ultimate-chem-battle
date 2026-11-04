class_name UiTokens
extends RefCounted

## Semantic colours for UI created in GDScript.  Static Controls use the same
## values through theme/game_theme.tres.  Chemistry-kind colours do not belong
## here; Recipes.KIND_COLOR remains their single source of truth.

const INK_DEEP := Color("0b0912")
const INK_PANEL := Color("171321")
const STONE := Color("211b2c")
const STONE_RAISED := Color("2b2337")
const BRASS_DARK := Color("6e5129")
const BRASS := Color("b88a45")
const QUEST_GOLD := Color("f2c66d")
const ARCANE := Color("72c7d4")
const PARCHMENT := Color("f3ead4")
const TEXT := Color("eee8f2")
const TEXT_MUTED := Color("aaa1b5")
const CARD_SURFACE := Color("1c2030")
const SUCCESS := Color("7bdca3")
const DANGER := Color("ed6a67")

const RADIUS_SMALL := 6
const RADIUS_NORMAL := 10
const RADIUS_LARGE := 14
const BORDER_NORMAL := 1
const BORDER_FOCUS := 2

const MOTION_FAST := 0.12
const MOTION_NORMAL := 0.22
const MOTION_SLOW := 0.40
