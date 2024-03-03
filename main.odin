package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

MouseTimeSpan :: struct {start, end: f32}

TimeBlock :: struct {
    start, duration: f32,
    text: strings.Builder,
}

FONTSIZE :: 24
CLOCKSIZE :: 10
HOUR_RECT_W :: 500
HOUR_RECT_H :: 50
N_LAYERS :: 4
UTC_OFFSET :: -5

screen_w, screen_h: f32
layer_w, layer_h: f32
number_w, number_h: f32
timeblocks: [N_LAYERS][dynamic]TimeBlock
mousetime: MouseTimeSpan
clock: f32
font: rl.Font
cam: rl.Camera2D
dt: f32

main :: proc() {
    initial_screen_w: i32 = 2 * HOUR_RECT_W
    initial_screen_h: i32 = (HOUR_RECT_H + CLOCKSIZE) * N_LAYERS
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    
    rl.SetWindowState({.WINDOW_RESIZABLE})
    defer rl.CloseWindow()

    cam.zoom = 1.0
    
    font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    number_w, number_h = get_number_dimentions()
    layer_w, layer_h = get_layer_dimentions()
    
    initial_screen_w += i32(number_w)
    initial_screen_h += i32(number_h * N_LAYERS)
    rl.SetWindowSize(initial_screen_w, initial_screen_h)
    
    append_timeblock(0, .5, 1)
    fmt.println(timeblocks)
    strings.write_string(&timeblocks[0][0].text, "sample text")
    strings.write_byte(&timeblocks[0][0].text, 0)

    for !rl.WindowShouldClose() {
        dt = rl.GetFrameTime()
        screen_w = auto_cast rl.GetScreenWidth()
        screen_h = auto_cast rl.GetScreenHeight()
        clock = get_current_hour()

        center_offset := rl.Vector2{0, 0}
        if screen_h > N_LAYERS*layer_h do center_offset.y = screen_h/2 - N_LAYERS*layer_h/2

        // Moving the camera
        if mv := rl.GetMouseWheelMove(); mv != 0 {
            cam.target.x += mv * HOUR_RECT_W * 0.25
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.H) {
            goto_hour(auto_cast clock)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.A) {
            goto_hour(0)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.E) {
            goto_hour(23)
        }
        cam.target.x = clamp(cam.target.x, 0, 24*HOUR_RECT_W)

        rl.ClearBackground(rl.BLACK)
        rl.BeginDrawing()

        // Cursor HUD background
        for i in 0..<N_LAYERS {
            color := rl.Color{35, 35, 85, 255}
            pos := rl.Vector2{0, f32(i) * layer_h} + center_offset
            rl.DrawRectangleV(pos, {screen_w, CLOCKSIZE}, color)
        }
        
        rl.BeginMode2D(cam)

    	// Getting the mouse layer
    	mpos := rl.GetMousePosition()
    	mpos_world := rl.GetScreenToWorld2D(mpos, cam)
    	mlayer := get_mouse_layer(mpos, center_offset)
    	on_hour_block := is_mouse_on_hour_block(mpos_world.x, mlayer)
    	if on_hour_block {
    	    x := mpos_world.x - number_w
    	    t := f32(HOUR_RECT_W / 60)
    	    pos := t * math.floor(x / t)
    	    if rl.IsMouseButtonPressed(.LEFT) {
    	       mousetime.start = math.ceil(60*pos / HOUR_RECT_W)
    	    }
    	    if rl.IsMouseButtonReleased(.LEFT) {
    	       mousetime.end = math.ceil(60*pos / HOUR_RECT_W)
        	   
        	   if mousetime.start != mousetime.end {
        	       {
        	           using mousetime
        	           if start > end do start, end = end, start
        	       }
        	       start := mousetime.start / 60
        	       duration := (mousetime.end - mousetime.start) / 60
        	       append_timeblock(mlayer, start, duration)
        	       last := len(timeblocks[mlayer]) - 1
        	       strings.write_string(&timeblocks[mlayer][last].text, "sample text")
                   strings.write_byte(&timeblocks[mlayer][last].text, 0)
        	   }
    	    }
    	}
	
        for i in 0..<N_LAYERS {
            render_clock(i, center_offset)
            render_layer(i, center_offset)
        }

        rl.EndMode2D()

    	// Drawing time blocks textboxes
    	for i in 0..<N_LAYERS {
        	render_timeblocks(i, center_offset)
    	}

        rl.EndDrawing()
    }
}

render_clock :: proc(layer: int, offset := rl.Vector2{0, 0}) {
    pos := rl.Vector2{clock * HOUR_RECT_W + number_w, layer_h * f32(layer)}

    if layer == 0 do rl.DrawLineV({pos.x, 0}, {pos.x, screen_h}, {255, 255, 255, 100})

    v1: rl.Vector2 = ({0.5, 1} - {.5, 0}) * CLOCKSIZE + pos + offset
    v2: rl.Vector2 = ({1.0, 0} - {.5, 0}) * CLOCKSIZE + pos + offset
    v3: rl.Vector2 = ({0.0, 0} - {.5, 0}) * CLOCKSIZE + pos + offset
    
    rl.DrawTriangle(v1, v2, v3, rl.GREEN)
}

render_layer :: proc(layer: int, offset := rl.Vector2{0, 0}) {
    for hour: f32; hour < 24; hour += 1 {

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
            h = (sin(PI*x - PI/2)*.5 + .5) * (280 - 150) + 150 // From 150 to 280
            s = cos(2*PI*x)*.25 + .75
            v = cos(2*PI*x - PI)*.35 + .65
            a = cos(2*PI*x - PI)*.20 + .80
        }
        color := rl.ColorAlpha(rl.ColorFromHSV(h, s, v), a)
        rl.DrawRectangleRounded(rect, 0.25, 10, color)

        // Padding for the cursor background.
        {
            thick :: 4
            start := rect_pos - {0, number_h + CLOCKSIZE}
            end := start + {0, CLOCKSIZE}
            rl.DrawLineEx(start, end, thick, rl.BLACK)
            
            if hour == 23 {
                start += {HOUR_RECT_W, 0}
                end := start + {0, CLOCKSIZE}
                rl.DrawLineEx(start, end, thick, rl.BLACK)
            }
        }

        // Padding between the hours.
        {
            thick :: 2
            start := rect_pos
            end := start + {0, HOUR_RECT_H}
            rl.DrawLineEx(start, end, thick, rl.BLACK)
        }
        
        // Draw text at the top of the block
        hour_text := rl.TextFormat("%i", i32(hour))
        text_pos := rect_pos + rl.Vector2{0, -number_h/2}
        render_text_centered(hour_text, text_pos)

        // Draw the number 24
        if hour == 23 {
            hour_text := rl.TextFormat("%i", 24)
            text_pos := rect_pos + rl.Vector2{HOUR_RECT_W, -number_h/2}
            render_text_centered(hour_text, text_pos)
        }
        
        // Draw lines to indicate half and quarter an hour.
        for i in 1..<4 {
            start := rect_pos + {0.25*f32(i)*HOUR_RECT_W, 0}
            end := start - {0, number_h/2}
            rl.DrawLineEx(start, end, 1, rl.WHITE)
        }
        
        // Draw lines to indicate every one minute
        for i in 0..=60 {
            start := rect_pos + {f32(i*HOUR_RECT_W)/60, 0}
            end := start - {0, number_h/4}
            rl.DrawLineEx(start, end, 1, {255, 255, 255, 150})
        }
    }
}

render_timeblocks :: proc(layer: int, offset := rl.Vector2{0, 0}) {
	for _, i in timeblocks[layer] {
	    text := timeblock_cstring(&timeblocks[layer][i])
	    _, text_h := get_text_dimentions(text)

	    start := timeblocks[layer][i].start
	    duration := timeblocks[layer][i].duration
	    
	    empty_space: f32 = HOUR_RECT_H/4

	    rect_pos := rl.Vector2{
    		number_w + start * HOUR_RECT_W,
    		number_h + CLOCKSIZE + layer_h * f32(layer) + empty_space,
	    }
	    rect_pos += offset - cam.target

	    rect := rl.Rectangle{
    		rect_pos.x, rect_pos.y,
    		duration * HOUR_RECT_W, HOUR_RECT_H - 2*empty_space
	    }
	    rl.DrawRectangleRounded(rect, .25, 50, {13, 13, 13, 200})

	    pos: rl.Vector2 = rect_pos + {rect.width/2, rect.height/2}
	    render_text_centered(text, pos)
	}
}