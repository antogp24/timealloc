package main

import "core:fmt"
import "core:math"
import "core:time"

import rl "vendor:raylib"

screen_w, screen_h: f32
number_w, number_h: f32
font: rl.Font
clock: f32
layer_h: f32
dt: f32

// UTC-5 in my case
UTC_OFFSET :: -5

FONTSIZE :: 24
CLOCKSIZE :: 10
HOUR_RECT_W :: 450
HOUR_RECT_H :: 50
RECT_PADDING :: 0
WINDOW_PADDING_X :: 0
WINDOW_PADDING_Y :: 0
N_LAYERS :: 4

main :: proc() {
    initial_screen_w: i32 = 2 * (HOUR_RECT_W + RECT_PADDING) + WINDOW_PADDING_X
    initial_screen_h: i32 = (HOUR_RECT_H + CLOCKSIZE) * N_LAYERS + WINDOW_PADDING_Y
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    
    rl.SetWindowState({.WINDOW_RESIZABLE})
    defer rl.CloseWindow()

    cam := rl.Camera2D{}
    cam.zoom = 1.0
    
    font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    number_w, number_h = get_number_dimentions()
    
    initial_screen_w += i32(number_w)
    initial_screen_h += i32(number_h * N_LAYERS)
    rl.SetWindowSize(initial_screen_w, initial_screen_h)

    for !rl.WindowShouldClose() {
        dt = rl.GetFrameTime()
        screen_w = cast(f32)rl.GetScreenWidth()
        screen_h = cast(f32)rl.GetScreenHeight()

        layer_h = HOUR_RECT_H + CLOCKSIZE + number_h
        clock = get_current_hour()

        // Moving the camera
        if mv := rl.GetMouseWheelMove(); mv != 0 {
            using cam
            if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.LEFT_CONTROL) {
                target.y = clamp(target.y - mv * layer_h, 0, HOUR_RECT_H + CLOCKSIZE + number_h)
            } else {
                target.x = clamp(target.x + mv * HOUR_RECT_W * 0.25, 0, 24*HOUR_RECT_W)
            }
        }

        rl.ClearBackground(rl.BLACK)
        rl.BeginDrawing()

        // Cursor HUD background
        for i in 0..<N_LAYERS {
            color := rl.Color{35, 35, 85, 255}
            rl.DrawRectangleV({0, f32(i) * layer_h}, {screen_w, CLOCKSIZE}, color)
        }
        
        rl.BeginMode2D(cam)

        for i in 0..<N_LAYERS {
            render_clock(i)
            render_layer(i)
        }
        rl.EndMode2D()
        rl.EndDrawing()
    }
}

render_clock :: proc(layer: int) {
    pos := rl.Vector2{clock * (HOUR_RECT_W + RECT_PADDING*.75) + number_w, layer_h * f32(layer)}

    if layer == 0 do rl.DrawLineV({pos.x, 0}, {pos.x, screen_h}, {255, 255, 255, 100})

    v1: rl.Vector2 = ({0.5, 1} - {.5, 0}) * CLOCKSIZE + pos
    v2: rl.Vector2 = ({1.0, 0} - {.5, 0}) * CLOCKSIZE + pos
    v3: rl.Vector2 = ({0.0, 0} - {.5, 0}) * CLOCKSIZE + pos
    
    rl.DrawTriangle(v1, v2, v3, rl.GREEN)
}

render_layer :: proc(layer: int) {
    for hour: f32; hour < 24; hour += 1 {

        rect_pos := rl.Vector2{
            (HOUR_RECT_W + RECT_PADDING) * hour + number_w,
            (number_h + CLOCKSIZE) * f32(layer + 1) + HOUR_RECT_H * f32(layer),
        }
        
        rect := rl.Rectangle{rect_pos.x, rect_pos.y, HOUR_RECT_W, HOUR_RECT_H}
        h, s, v: f32
        x := hour / 23

        // Dynamically getting the color value based on the hour.
        {
            using math
            h = (sin(PI*x - PI/2)*.5 + .5) * 180
            s = .8 + sin(x)*.2 
            v = sin(2*PI*x - PI/2)*.4 + .5
        }
        rl.DrawRectangleRounded(rect, 0.4, 10, rl.ColorFromHSV(h, s, v))
        
        // Draw text at the top of the block
        hour_text := rl.TextFormat("%i", i32(hour))
        text_pos := rect_pos + rl.Vector2{0, -number_h/2}
        draw_text_centered(hour_text, text_pos)

        // Draw the number 24
        if hour == 23 {
            hour_text := rl.TextFormat("%i", 24)
            text_pos := rect_pos + rl.Vector2{HOUR_RECT_W + RECT_PADDING, -number_h/2}
            draw_text_centered(hour_text, text_pos)
        }
        
        // Draw lines to indicate half and quarter an hour.
        for i in 1..<4 {
            start := rect_pos + {0.25*f32(i)*HOUR_RECT_W, 0}
            end := start - {0, number_h/2}
            rl.DrawLineEx(start, end, 1, rl.WHITE)
        }
        
        // Draw lines to indicate every one minute
        for i in 1..=60 {
            start := rect_pos + {0.0166667*f32(i)*HOUR_RECT_W, 0}
            end := start - {0, number_h/4}
            rl.DrawLineEx(start, end, 1, {255, 255, 255, 150})
        }
    }
}

get_current_hour :: proc() -> f32 {
    t := time.now()
    t = time.time_add(t, UTC_OFFSET*time.Hour)
    h, m, s := time.clock_from_time(t)
    hours, minutes, seconds := f32(h), f32(m), f32(s)
    return hours + minutes/60 + seconds/3600
}

get_number_dimentions :: proc() -> (f32, f32) {
    measure := rl.MeasureTextEx(font, "0", FONTSIZE, 0)
    return measure.x, measure.y
} 

draw_text_centered :: proc(text: cstring, pos: rl.Vector2, color := rl.WHITE) {
    spacing :: 0
    measure := rl.MeasureTextEx(font, text, FONTSIZE, spacing)
    rl.DrawTextEx(font, text, pos - measure/2, FONTSIZE, spacing, color)
}
