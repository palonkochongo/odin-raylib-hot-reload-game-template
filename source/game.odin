/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
      pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g_mem` global
      variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180
PIXEL_WINDOW_WIDTH :: 320 //Animal Well style
PLAYER_START_POS_X :: 30
PLAYER_START_POS_Y :: 30

Game_Memory :: struct {
	player:      Player,
	some_number: int,
	run:         bool,
	platforms:   [30]rl.Rectangle,
}

Player :: struct {
	player_pos:     rl.Vector2,
	player_texture: rl.Texture,
	player_rect:    rl.Rectangle,
	isGrounded: bool,
}


Collider :: struct {
	pos: rl.Vector2,
	size: rl.Vector2,
}

g_mem: ^Game_Memory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {
		zoom = h / PIXEL_WINDOW_HEIGHT,
		target = g_mem.player.player_pos,
		offset = {w / 2, h / 2},
	}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PIXEL_WINDOW_HEIGHT}
}

update :: proc() {

	player := &g_mem.player


	//Gravity
		g_mem.player.player_pos.y += rl.GetFrameTime() * 100
	updatePlayer(player, g_mem)
	g_mem.some_number += 1

	if rl.IsKeyPressed(.ESCAPE) {
		g_mem.run = false
	}
}

updatePlayer :: proc (player: ^Player, world: ^Game_Memory) {

	input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	input = linalg.normalize0(input)
	player.player_pos += input * rl.GetFrameTime() * 200

	for r in world.platforms {
		platCollider := getCollider(r)
		playerCollider := getPlayerCollider(player)
		coll, coll_fix, _ := colliding(playerCollider, platCollider)
		if coll {
			if coll_fix.y < 0 {
				player.player_pos += coll_fix
				player.isGrounded = true
			} else {
				player.player_pos += coll_fix
			}
		}
	}
}
getPlayerCollider :: proc (player: ^Player) -> Collider {
	return Collider {player.player_pos , {20, 24}}
}

getCollider :: proc (r1: rl.Rectangle) -> Collider {
	return Collider {{r1.x, r1.y}, {r1.width, r1.height}}
}

colliding :: proc (c1: Collider, c2: Collider) -> (bool, rl.Vector2, rl.Rectangle) {
	collRect := rl.GetCollisionRec({c1.pos.x, c1.pos.y, c1.size.x, c1.size.y}, {c2.pos.x, c2.pos.y, c2.size.x, c2.size.y})
	if collRect.width < collRect.height {
		onRight := c1.pos.x + c1.size.x / 2 > collRect.x
		return true, {onRight ? collRect.width : -collRect.width, 0}, collRect
	}
	if collRect.width > collRect.height {
		onTop := c1.pos.y + c1.size.y / 2 > collRect.y
		return true, {0, onTop ? collRect.height : -collRect.height}, collRect
	}
	return false, {}, {}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(game_camera())
	rl.DrawRectangleV({-30, -20}, {10, 10}, rl.GREEN)
	rl.DrawRectangleRec(g_mem.platforms[0], rl.BLUE)
	rl.DrawRectangleRec({g_mem.player.player_pos.x, g_mem.player.player_pos.y, 20, 24}, rl.GREEN)
	rl.DrawTextureEx(g_mem.player.player_texture, g_mem.player.player_pos, 0, 1, rl.WHITE)
	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	rl.DrawText(
		fmt.ctprintf(
			"some_number: %v\nplayer_pos: %v",
			g_mem.some_number,
			g_mem.player.player_pos,
		),
		5,
		5,
		8,
		rl.WHITE,
	)

	rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		run = true,
		some_number = 100,

		// You can put textures, sounds and music in the `assets` folder. Those
		// files will be part any release or web build.
		player = {
			player_texture = rl.LoadTexture("assets/round_cat.png"),
			player_pos = {PLAYER_START_POS_X, PLAYER_START_POS_Y},
			player_rect = rl.Rectangle{PLAYER_START_POS_X, PLAYER_START_POS_Y, 30, 30}},
		platforms = new([30]rl.Rectangle)^,
	}

	//setup some platforms.
	platform1 := rl.Rectangle {
		y = 70,
		width  = PIXEL_WINDOW_WIDTH,
		height = 10,
	}
	g_mem.platforms[0] = platform1

	game_hot_reloaded(g_mem)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g_mem.run
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `g_mem`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
