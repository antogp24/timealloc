package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

MouseTimeSpan :: struct {
    start, end: f32,
    registering: bool,
}

Time :: struct {hours, minutes: int}

Active :: struct {
    layer,            // active layer for timeline
    block,            // active block for current layer in timeline
    tblock: int,      // active block for timealloc interface
    timealloc: bool,  // timealloc interface for adding blocks
}

TimeBlock :: struct {
    start, duration: f32,
    using textbox: TextBox,
}

// Constants
FONTSIZE :: 24
FONTBIGSIZE :: 48
CLOCKSIZE :: 10
HOUR_RECT_W :: 400
HOUR_RECT_H :: 50
N_LAYERS :: 4
UTC_OFFSET :: -5

// Colors from solarized colorscheme
COLOR_BASE03           :: rl.Color{0, 43, 54, 255}
COLOR_BASE1            :: rl.Color{147, 161, 161, 255}
COLOR_BASE2            :: rl.Color{238, 232, 213, 255}
COLOR_YELLOW           :: rl.Color{181, 137, 0, 255}
COLOR_RED              :: rl.Color{220, 50, 47, 255}
COLOR_MAGENTA          :: rl.Color{211, 54, 130, 255}
COLOR_VIOLET           :: rl.Color{108, 113, 196, 255}
COLOR_BLUE             :: rl.Color{38, 139, 210, 255}
COLOR_CYAN             :: rl.Color{42, 161, 152, 255}
COLOR_GREEN            :: rl.Color{133, 153, 0, 255}
COLOR_BG               :: COLOR_BASE03
COLOR_TEXTBOX_ACTIVE   :: rl.Color{0, 33, 44, 200}
COLOR_TEXTBOX_INACTIVE :: rl.Color{0, 23, 34, 255}

// Globals
screen_w, screen_h: f32
layer_w, layer_h: f32
number_w, number_h: f32
big_number_w, big_number_h: f32
timeblocks: [N_LAYERS][dynamic]TimeBlock
timealloc_textboxes: [4]TextBox
active := Active{-1, -1, -1, false}
mousetime: MouseTimeSpan
clock: f32
font: rl.Font
font_big: rl.Font
cam: rl.Camera2D
elapsedtime: f64
dt: f32

keytimers := map[rl.KeyboardKey]f32 {
    .BACKSPACE = 0,
    .ENTER     = 0,
    .UP        = 0,
    .DOWN      = 0,
    .LEFT      = 0,
    .RIGHT     = 0,
}

main :: proc() {
    initial_screen_w: i32 = 2 * HOUR_RECT_W
    initial_screen_h: i32 = (HOUR_RECT_H + CLOCKSIZE) * N_LAYERS
    rl.SetTargetFPS(60)
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    defer rl.CloseWindow()

    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetExitKey(.KEY_NULL)
    cam.zoom = 1.0
    
    font = resource_load_font("assets/Inter-Regular.ttf", FONTSIZE)
    font_big = resource_load_font("assets/Inter-Regular.ttf", FONTBIGSIZE)
    number_w, number_h = get_number_dimentions()
    layer_w, layer_h = get_layer_dimentions()

    big_number_w, big_number_h = get_number_dimentions(font_big, FONTBIGSIZE)
    
    initial_screen_w += i32(number_w)
    initial_screen_h += i32(number_h * N_LAYERS)
    rl.SetWindowSize(initial_screen_w, initial_screen_h)

    // Adding a null terminator to all fields in the timealloc interface
    for i in 0..<len(timealloc_textboxes) {
	strings.write_byte(&timealloc_textboxes[i].text, 0)
    }
    
    for !rl.WindowShouldClose() {
        elapsedtime = rl.GetTime()
        dt = rl.GetFrameTime()
        screen_w = cast(f32) rl.GetScreenWidth()
        screen_h = cast(f32) rl.GetScreenHeight()
        clock = get_current_hour()
        
        center_offset: rl.Vector2
        if screen_h > N_LAYERS*layer_h {
            center_offset.y = screen_h/2 - N_LAYERS*layer_h/2
        }

        // Moving the camera
        if mv := rl.GetMouseWheelMove(); mv != 0 {
            cam.target.x  += mv * HOUR_RECT_W * 0.25
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.A) {
            goto_hour(0)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.E) {
            goto_hour(23)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.D) {
            goto_hour(auto_cast clock)
        }
        cam.target.x = clamp(cam.target.x, 0, 24*HOUR_RECT_W)
        
	// Toggling timealloc interface
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.T) {
	    using active
	    timealloc = !timealloc
	    if timealloc do tblock = 0
	    else         do tblock = -1
	}
	
	// Escaping out of stuff
        if rl.IsKeyPressed(.ESCAPE) {
	    active.block = -1
	    active.timealloc = false
        }

	// Typing in the timealloc textboxes
	if active.timealloc {
            chr := rl.GetCharPressed()
	    textbox := &timealloc_textboxes[active.tblock]
	    using textbox

	    type := active.tblock % 2
	    buf_register_typing_numbers(textbox, u8(chr), 2 + 1)

	    if rl.IsKeyPressed(.LEFT) {
		active.tblock -= 1
	    } else if rl.IsKeyPressed(.RIGHT) {
		active.tblock += 1
	    } else if rl.IsKeyPressed(.UP) {
		if len(text.buf) == 1 {
		    inject_at(&text.buf, cursor, '0')
		    cursor += 1
		} else {
		}
	    } else if rl.IsKeyPressed(.DOWN) {
		if len(text.buf) == 1 {
		    if type == 0 do inject_at(&text.buf, cursor, '2', '4')
		    else         do inject_at(&text.buf, cursor, '6', '0')
		    cursor += 2
		} else {
		}
	    } else if rl.IsKeyPressed(.BACKSPACE) {
		buf_backspace(textbox)
	    }
	    active.tblock = clamp(active.tblock, 0, 4 - 1)
	}

        // Typing in the timeline textboxes
        if active.layer != -1 && active.block != -1 && !active.timealloc {
            for key in keytimers {
                timer_update(key, dt)
            }
            key := rl.GetKeyPressed()
            chr := rl.GetCharPressed()
            block := &timeblocks[active.layer][active.block]
            using block

	    buf_register_typing(&textbox, cast(u8)chr)

            // Text Editing
            if key_is_pressed_or_down(key, .DOWN) {
		buf_goto_end(&textbox)

            } else if key_is_pressed_or_down(key, .UP) {
		buf_goto_start(&textbox)

            } else if key_is_pressed_or_down(key, .LEFT) {
                if rl.IsKeyDown(.LEFT_CONTROL) {
		    buf_move_left_by_word(&textbox)
                } else {
		    buf_move_left(&textbox)
                }

            } else if key_is_pressed_or_down(key, .RIGHT) {
                if rl.IsKeyDown(.LEFT_CONTROL) {
		    buf_move_right_by_word(&textbox)
                } else {
		    buf_move_right(&textbox)
                }

            } else if key_is_pressed_or_down(key, .BACKSPACE) {
                if rl.IsKeyDown(.LEFT_CONTROL) {
		    buf_backspace_by_word(&textbox)
                } else if len(text.buf) > 0 {
		    buf_backspace(&textbox)
                }
            } else if rl.IsKeyPressed(.ENTER) {
		active.block = -1
	    }
        }
        
        // Mouse interaction
        mpos := rl.GetMousePosition()
        mpos_world := rl.GetScreenToWorld2D(mpos, cam)
        mlayer := get_mouse_layer(mpos, center_offset)
        mouse_on_hour_block := is_mouse_on_hour_block(mpos_world.x, mlayer)
        
        if rl.IsMouseButtonPressed(.LEFT) && !mouse_on_hour_block {
	    active.layer, active.block = -1, -1
        }       
        
        if mouse_on_hour_block && !active.timealloc {
            // snapping the mouse position to minutes
            x := mpos_world.x - number_w
            t := f32(HOUR_RECT_W / 60)
            pos := t * math.floor(x / t)
            
            if rl.IsMouseButtonPressed(.LEFT) {
                mousetime.start = math.ceil(60*pos / HOUR_RECT_W)
                
                collided := get_collided_timeblock(mlayer, mpos, center_offset, 0)
                mousetime.registering = (collided == -1)
		active.block = -1
                
            } else if rl.IsMouseButtonReleased(.LEFT) {
                mousetime.end = math.ceil(60*pos / HOUR_RECT_W)
                
                collided := get_collided_timeblock(mlayer, mpos, center_offset, 0)
                if mousetime.registering do mousetime.registering = (collided == -1)
                
                if mousetime.start != mousetime.end && mousetime.registering {
                    // Swapping if needed.
                    if mousetime.start > mousetime.end {
                        using mousetime
                        start, end = end, start
                    }
                    
                    start := mousetime.start / 60
                    duration := (mousetime.end - mousetime.start) / 60
                    append_timeblock(mlayer, start, duration)
                    
                    active.layer = mlayer
                    active.block = len(timeblocks[mlayer]) - 1
                    
                } else if collided != -1 {
                    active.layer = mlayer
                    active.block = collided
                }
            }
        }

        rl.ClearBackground(COLOR_BG)
        rl.BeginDrawing()

        // Cursor HUD background
        for layer in 0..<N_LAYERS {
	    is_active := layer == active.layer
            color: rl.Color = COLOR_RED if is_active else COLOR_VIOLET
            pos := rl.Vector2{0, f32(layer) * layer_h} + center_offset
            rl.DrawRectangleV(pos, {screen_w, CLOCKSIZE}, color)
        }
        
        rl.BeginMode2D(cam)
        
        for layer in 0..<N_LAYERS {
            render_layer(layer, center_offset)
            render_clock(layer, center_offset)
        }

        rl.EndMode2D()

        // Drawing time blocks textboxes
        for layer in 0..<N_LAYERS {
            render_timeblocks(layer, center_offset)
        }

	// Drawing timealloc HUD
	if active.timealloc {
	    render_timealloc_interface()
	}

        rl.EndDrawing()
    }
}

render_clock :: proc(layer: int, offset: rl.Vector2) {
    pos := rl.Vector2{clock * HOUR_RECT_W + number_w, layer_h * f32(layer)}

    if layer == 0 {
	rl.DrawLineV({pos.x, 0}, {pos.x, screen_h}, rl.ColorAlpha(COLOR_BASE2, 0.4))
    }

    v1: rl.Vector2 = ({0.5, 1} - {.5, 0}) * CLOCKSIZE + pos + offset
    v2: rl.Vector2 = ({1.0, 0} - {.5, 0}) * CLOCKSIZE + pos + offset
    v3: rl.Vector2 = ({0.0, 0} - {.5, 0}) * CLOCKSIZE + pos + offset
    
    rl.DrawTriangle(v1, v2, v3, COLOR_GREEN)
}

render_layer :: proc(layer: int, offset: rl.Vector2) {
    for hour in f32(0)..<24 {
        
        rect_pos := rl.Vector2{
            HOUR_RECT_W * hour + number_w,
            (number_h + CLOCKSIZE) * f32(layer + 1) + HOUR_RECT_H * f32(layer),
        }
        rect_pos += offset
        
        rect := rl.Rectangle{rect_pos.x, rect_pos.y, HOUR_RECT_W, HOUR_RECT_H}
        h, s, v, a: f32

        // Dynamically getting the color value based on the hour.
        x := hour / 23
        {
            using math
            h = (sin(PI*x - PI/2)*.5 + .5) * (280 - 175) + 175 // From 175 to 280
            s = cos(2*PI*x)*.25 + .75
            v = cos(2*PI*x - PI)*.45 + .55
            a = cos(2*PI*x - PI)*.20 + .80
        }
        color := rl.ColorAlpha(rl.ColorFromHSV(h, s, v), a)
        rl.DrawRectangleRounded(rect, 0.25, 10, color)

        // Padding for the cursor background.
        {
            thick :: 4
            start := rect_pos - {0, number_h + CLOCKSIZE}
            end := start + {0, CLOCKSIZE}
            rl.DrawLineEx(start, end, thick, COLOR_BG)
            
            if hour == 23 {
                start += {HOUR_RECT_W, 0}
                end := start + {0, CLOCKSIZE}
                rl.DrawLineEx(start, end, thick, COLOR_BG)
            }
        }

        // Padding between the hours.
        {
            thick :: 2
            start := rect_pos
            end := start + {0, HOUR_RECT_H}
            rl.DrawLineEx(start, end, thick, COLOR_BG)
        }
        
        // Draw text at the top of the block
        hour_text := rl.TextFormat("%i", i32(hour))
	text_len := 2 if hour >= 10 else 1
        text_pos := rect_pos + rl.Vector2{0, -number_h/2}
        render_text_centered(hour_text, text_len, text_pos, tint=COLOR_BASE2)

        // Draw the number 24 at the end
        if hour == 23 {
            hour_text := rl.TextFormat("%i", 24)
            text_pos := rect_pos + rl.Vector2{HOUR_RECT_W, -number_h/2}
	    render_text_centered(hour_text, 2, text_pos, tint=COLOR_BASE2)
        }
        
        // Draw lines to indicate half and quarter an hour.
        for i in 1..<4 {
            start := rect_pos + {0.25*f32(i)*HOUR_RECT_W, 0}
            end := start - {0, number_h/2}
            rl.DrawLineEx(start, end, 1, COLOR_BASE2)
        }
        
        // Draw lines to indicate every one minute
        for i in 0..=60 {
            start := rect_pos + {f32(i*HOUR_RECT_W)/60, 0}
            end := start - {0, number_h/4}
            rl.DrawLineEx(start, end, 1, rl.ColorAlpha(COLOR_BASE2, 0.5))
        }
    }
}

render_timeblocks :: proc(layer: int, offset: rl.Vector2) {
    for _, i in timeblocks[layer] {
        text := cast(cstring) raw_data(timeblocks[layer][i].text.buf[:])
        text_len := len(timeblocks[layer][i].text.buf) - 1
        text_w, text_h := get_text_dimentions(text, text_len)
        
        is_active := (active.block == i && active.layer == layer) && !active.timealloc
        cursor := timeblocks[layer][i].cursor
        
	color: rl.Color = COLOR_TEXTBOX_ACTIVE if is_active else COLOR_TEXTBOX_INACTIVE
        
        rect := get_timeblock_rect(layer, i, offset, HOUR_RECT_H/4)
        rl.DrawRectangleRounded(rect, 1, 50, color)
	rl.DrawRectangleRoundedLines(rect, 1, 50, 2, COLOR_MAGENTA if is_active else COLOR_CYAN)

        rect_center := rl.Vector2{rect.x + rect.width/2, rect.y + rect.height/2}
	render_text_centered(text, text_len, rect_center, tint=COLOR_BASE2)

        if is_active {
            offset := get_text_offset(text, cursor)
            cursor_pos: rl.Vector2 = rect_center + {offset - text_w/2, 0}
            cursor_h := rect.height - 10
            
            start: rl.Vector2 = cursor_pos - {0, cursor_h/2}
            end:   rl.Vector2 = cursor_pos + {0, cursor_h/2}
            
            // Blinking cursor
            alpha := math.cos(math.PI*f32(2*elapsedtime))*0.35 + 0.65
	    rl.DrawLineEx(start, end, 2, rl.ColorAlpha(COLOR_BLUE, alpha)) 
        }
    }
}

get_timeblock_rect_from_existing :: proc(layer, i: int, offset: rl.Vector2, empty_space: f32) -> rl.Rectangle {
    start := timeblocks[layer][i].start
    duration := timeblocks[layer][i].duration

    rect_pos := rl.Vector2{
        number_w + start * HOUR_RECT_W,
        number_h + CLOCKSIZE + layer_h * f32(layer) + empty_space,
    }
    rect_pos += offset - cam.target

    rect := rl.Rectangle{
        rect_pos.x,
        rect_pos.y,
        duration * HOUR_RECT_W,
        HOUR_RECT_H - 2*empty_space,
    }
    return rect
}

get_timeblock_rect_from_new :: proc(layer: int, start, duration: f32, offset: rl.Vector2, empty_space: f32) -> rl.Rectangle {
    rect_pos := rl.Vector2{
        number_w + start * HOUR_RECT_W,
        number_h + CLOCKSIZE + layer_h * f32(layer) + empty_space,
    }
    rect_pos += offset - cam.target

    rect := rl.Rectangle{
        rect_pos.x,
        rect_pos.y,
        duration * HOUR_RECT_W,
        HOUR_RECT_H - 2*empty_space,
    }
    return rect
}

get_timeblock_rect :: proc{get_timeblock_rect_from_existing, get_timeblock_rect_from_new}

get_collided_timeblock_pos :: proc(layer: int, pos, offset: rl.Vector2, empty_space: f32) -> int {
    collided := -1
    for _, i in timeblocks[layer] {
        rect := get_timeblock_rect(layer, i, offset, empty_space)
        if rl.CheckCollisionPointRec(pos, rect) {
            collided = i
            break
        }
    }
    return collided
}

get_collided_timeblock_rect :: proc(layer: int, rect: rl.Rectangle, offset: rl.Vector2, empty_space: f32) -> int {
    collided := -1
    for _, i in timeblocks[layer] {
        rect_ := get_timeblock_rect(layer, i, offset, empty_space)
        if rl.CheckCollisionRecs(rect, rect_) {
            collided = i
            break
        }
    }
    return collided
}

get_collided_timeblock :: proc{get_collided_timeblock_pos, get_collided_timeblock_rect}

reset_all_active_timeblocks :: proc() {
    active.layer, active.block = -1, -1
}

timealloc :: proc(start, end: Time, offset: rl.Vector2) -> (success: bool) {
    start_hour := hms_to_hours(auto_cast start.hours, auto_cast start.minutes, 0)
    end_hour := hms_to_hours(auto_cast end.hours, auto_cast end.minutes, 0)
    if start_hour > end_hour do start_hour, end_hour = end_hour, start_hour

    duration := end_hour - start_hour

    layer: int
    for layer = 0; layer <= N_LAYERS; layer += 1 {
        if layer == N_LAYERS do break
        rect := get_timeblock_rect(layer, start_hour, duration, offset, 0)
        collided := get_collided_timeblock(layer, rect, offset, 0)
        if collided == -1 do break
    }
    if layer == N_LAYERS do return false

    append_timeblock(layer, start_hour, duration)
    return true
}

render_timealloc_interface :: proc() {
    // Transparent Background
    rl.DrawRectangleRec({0, 0, screen_w, screen_h}, {0, 43, 54, 200})

    padding :: 5
    {
	text :: "timealloc("
	text_w, _ := get_text_dimentions(text, len(text), font_big, FONTBIGSIZE)
	offset := rl.Vector2{-(2*big_number_w + padding) * 2 - padding - text_w/2, 0}
	render_text_centered(text, len(text), {screen_w/2, screen_h/2} + offset, font_big, FONTBIGSIZE, tint=COLOR_VIOLET)
    }
    {
	text :: ","
	render_text_centered(text, len(text), {screen_w/2, screen_h/2}, font_big, FONTBIGSIZE, tint=COLOR_VIOLET)
    }
    {
	text :: ")"
	text_w, _ := get_text_dimentions(text, len(text), font_big, FONTBIGSIZE)
	offset := rl.Vector2{(2*big_number_w + padding) * 2 + padding + text_w/2, 0}
	render_text_centered(text, len(text), {screen_w/2, screen_h/2} + offset, font_big, FONTBIGSIZE, tint=COLOR_VIOLET)
    }
    {
	text :: "start"
	offset := rl.Vector2{-(2*big_number_w + padding) * 1 - padding, -big_number_h}
	render_text_centered(text, len(text), {screen_w/2, screen_h/2} + offset, tint=COLOR_YELLOW)
    }
    {
	text :: "end"
	offset := rl.Vector2{(2*big_number_w + padding) * 1 + padding, -big_number_h}
	render_text_centered(text, len(text), {screen_w/2, screen_h/2} + offset, tint=COLOR_YELLOW)
    }

    // Offset to apply to all elements in the loop, to move them to the center of the screen.
    offset := rl.Vector2{
	screen_w/2 - 4*big_number_w - 1.5*padding,
	screen_h/2 - big_number_h/2
    }

    for i in 0..<4 {
	is_active := (active.tblock == i)
	pos: rl.Vector2 = {(2*big_number_w + padding) * f32(i), 0} + offset
	if i < 2 do pos -= {padding, 0}
	else     do pos += {padding, 0}

	rect := rl.Rectangle{pos.x, pos.y, big_number_w*2, big_number_h}
	rect_center := rl.Vector2{rect.x + rect.width/2, rect.y + rect.height/2}
	rect_color: rl.Color = COLOR_TEXTBOX_ACTIVE if is_active else COLOR_TEXTBOX_INACTIVE
	rl.DrawRectangleRounded(rect, 0.5, 50, rect_color)

	// Drawing h and m labels
	{
	    text: cstring = "h" if i % 2 == 0 else "m"
	    pos := rect_center + rl.Vector2{0, rect.height/2 + big_number_h/2}
	    rl.DrawCircleV(pos, 2 + number_w, {0, 23, 34, 255})
	    render_text_centered(text, len(text), pos, tint=COLOR_GREEN)
	}

	pos += {rect.width/2, rect.height/2}
	cursor := timealloc_textboxes[i].cursor
	text := cast(cstring) raw_data(timealloc_textboxes[i].text.buf)
	text_len := len(timealloc_textboxes[i].text.buf) - 1
	text_w, _ := get_text_dimentions(text, len(text), font_big, FONTBIGSIZE)
	render_text_centered(text, text_len, pos, font_big, FONTBIGSIZE, tint=COLOR_BASE1)

	if is_active {
	    offset := get_text_offset(text, cursor, font_big, FONTBIGSIZE)
	    cursor_pos: rl.Vector2 = rect_center + {offset - text_w/2, 0}
	    cursor_h := rect.height - 10

	    start: rl.Vector2 = cursor_pos - {0, cursor_h/2}
	    end:   rl.Vector2 = cursor_pos + {0, cursor_h/2}

	    // Blinking cursor
	    alpha := math.cos(math.PI*f32(2*elapsedtime))*0.35 + 0.65
	    rl.DrawLineEx(start, end, 2, rl.ColorAlpha(COLOR_BLUE, alpha)) 
	}
    }
}
