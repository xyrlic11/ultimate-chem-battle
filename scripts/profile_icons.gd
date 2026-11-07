extends RefCounted
## Code-native 16 x 16 skill sprites. Nearest-neighbour scaling preserves the grid.
const PALETTE = {"o":Color("242338"), "s":Color("4b6385"), "b":Color("58abd7"), "h":Color("b6edee"), "g":Color("7acb83"), "p":Color("9b6ccb"), "r":Color("e35c50"), "y":Color("ffca67")}
const SPRITES = {
	"shield": ["................","................","...oooooooooo...","...ohhhhhhhso...","...ohbbbbbbso...","...ohbbbbbbso...","...ohbbbbbbso...","...ohbbbbbbso...","....obbbbbso....","....obbbbbso....",".....obbbso.....","......obso......",".......oo.......","................","................","................"],
	"heal": ["................","................","......oooo......","......ohgo......","......ohgo......","...oooohgoooo...","...ohhhhhgggo...","...oggggggggo...","...ooooggoooo...","......oggo......","......oggo......","......oooo......","................","................","................","................"],
	"fire": ["................",".......o........","......oro.......",".....oryo.......",".....oryro......","...o.oryro......","..orooryyro.....","..oryoryyro.....","..oryyyyyro.....","..oryyhyyro.....","...oryhyro......","...oryyyro......","....orroo.......",".....ooo........","................","................"],
	"poison": ["................","......oooo......","......ohpo......","......ohpo......",".....oohpoo.....","....ohhhhppo....","...ohgggggppo...","...ohgggggppo...","...ogggggggpo...","...ogogggogpo...","...ogggogggpo...","....oggggppo....",".....oooooo.....","................","................","................"],
	"break": ["................","...oooooooooo...","...ohhhosssso...","...ohhoryssso...","...ohorysssso...","...ohorysssso...","...ohhoryssso...","....ohorysso....","....ohorysso....",".....orysso.....",".....oryso......",".....oroo.......",".....oo.........","................","................","................"],
	"clock": ["................",".....oooooo.....","....ohhhhsoo....","...ohbbbbbsso...","..ohbbbobbbso...","..ohbbbobbbso...","..ohbbbobbbso...","..ohbbbooooso...","..ohbbbbbbbso...","..ohbbbbbbbso...","...osbbbbbso....","....ossssso.....",".....ooooo......","................","................","................"]}
static var cache: Dictionary = {}

static func skill(effect: String) -> Texture2D:
	var key := "fire"
	if effect in ["heal", "cleanse_heal"]: key = "heal"
	elif effect in ["shield", "guard", "self_guard", "cleanse_shield"]: key = "shield"
	elif effect in ["dot", "rust"]: key = "poison"
	elif effect in ["armor_break", "stacking_armor_break", "attack_down"]: key = "break"
	elif effect == "cooldown_reduce": key = "clock"
	if cache.has(key): return cache[key]
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 16:
		for x in 16:
			var pixel: String = SPRITES[key][y][x]
			if PALETTE.has(pixel): image.set_pixel(x, y, PALETTE[pixel])
	cache[key] = ImageTexture.create_from_image(image)
	return cache[key]

static func stat(health: bool) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/ui/profile/hearts.jpg" if health else "res://assets/ui/profile/attack.jpg")
	texture.region = Rect2(30, 343, 574, 530) if health else Rect2(25, 50, 350, 300)
	return texture

static func paper_key() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); float paper=step(0.975,min(c.r,min(c.g,c.b))); COLOR=vec4(c.rgb,c.a*(1.0-paper)); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
