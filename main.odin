package main

import "core:fmt"
import "core:strings"
import "core:math"
import rl "vendor:raylib"

screen_w, screen_h: f32
font: rl.Font
dt: f32
schedule: [24]cstring

FONTSIZE :: 18
HOUR_BLOCK_SIZE :: 50
WINDOW_PADDING_X :: 0
WINDOW_PADDING_Y :: 0
BLOCK_PADDING :: 2

main :: proc() {
    initial_screen_w: i32 = 12*HOUR_BLOCK_SIZE + 12*BLOCK_PADDING + WINDOW_PADDING_X
    initial_screen_h: i32 = 2*HOUR_BLOCK_SIZE + WINDOW_PADDING_Y
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    
    rl.SetWindowState({.WINDOW_RESIZABLE})
    defer rl.CloseWindow()
    
    font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    number_w, number_h := get_number_dimentions()
    
    initial_screen_w += i32(2*number_w)
    initial_screen_h += i32(2*number_h)
    rl.SetWindowSize(initial_screen_w, initial_screen_h)
    
    for !rl.WindowShouldClose() {
        dt = rl.GetFrameTime()
        screen_w = cast(f32)rl.GetScreenWidth()
        screen_h = cast(f32)rl.GetScreenHeight()
        
        for hour: f32; hour <= 24; hour += 1 {
            rect_pos: rl.Vector2
            if (hour < 12) { 
                rect_pos.x = screen_w/2 + HOUR_BLOCK_SIZE*(hour - 6) + BLOCK_PADDING*(hour - 6)
                rect_pos.y = screen_h/2 - HOUR_BLOCK_SIZE
            } else {
                rect_pos.x = screen_w/2 + HOUR_BLOCK_SIZE*(hour - 18) + BLOCK_PADDING*(hour - 18)
                rect_pos.y = screen_h/2
            }
            rect := rl.Rectangle{rect_pos.x, rect_pos.y, HOUR_BLOCK_SIZE, HOUR_BLOCK_SIZE}
            h, s, v: f32
            x := hour / 24
            {
                using math
                h = (sin(PI*x - PI/2)*.5 + .5) * 180
                s = .8 + sin(x)*.2 
                v = sin(2*PI*x - PI/2)*.4 + .5
            }
            if (hour < 24) do rl.DrawRectangleRounded(rect, 0.25, 10, rl.ColorFromHSV(h, s, v))
            
            hour_text := rl.TextFormat("%i", cast(i32)hour)
            text_pos := rect_pos + rl.Vector2{0, -number_h/2}
            draw_text_centered(hour_text, text_pos)
        }
        // draw_text_centered("Some sample text!", {screen_w/2, screen_h/2})
        
        rl.ClearBackground(rl.BLACK)
        rl.BeginDrawing()
        rl.EndDrawing()
    }
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