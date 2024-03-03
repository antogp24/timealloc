package main

import "core:fmt"
import "core:time"
import "core:strings"
import rl "vendor:raylib"

append_timeblock :: proc(layer: int, start, duration: f32) {
    append(&timeblocks[layer], TimeBlock{start, duration, strings.builder_make()})
}

hours_to_hms :: proc(hours: f32) -> (h, m, s: f32) {
    whole := f32(int(hours))
    decimal := hours - f32(int(hours))

    h = whole
    m = f32(int(decimal * 60))
    s = ((decimal * 60) - m) * 60
    return h, m, s
}

hms_to_hours :: proc(h, m, s: f32) -> (hours: f32) {
    return h + m/60 + s/3600
}

timeblock_cstring :: proc(using t: ^TimeBlock) -> cstring {
    return cstring(raw_data(text.buf[:]))
}

goto_hour :: proc(hour: int) {
    cam.target.x = f32(hour) * HOUR_RECT_W
}

get_current_hour :: proc() -> f32 {
    t := time.now()
    t = time.time_add(t, UTC_OFFSET*time.Hour)
    h, m, s := time.clock_from_time(t)
    return hms_to_hours(f32(h), f32(m), f32(s))
}

get_layer_dimentions :: proc() -> (f32, f32) {
    return 24*HOUR_RECT_W, HOUR_RECT_H + CLOCKSIZE + number_h
}

get_text_dimentions :: proc(text: cstring) -> (f32, f32) {
    measure := rl.MeasureTextEx(font, text, FONTSIZE, 0)
    return measure.x, measure.y
} 

get_number_dimentions :: proc() -> (f32, f32) {
    measure := rl.MeasureTextEx(font, "0", FONTSIZE, 0)
    return measure.x, measure.y
} 

render_text :: proc(text: cstring, pos: rl.Vector2, color := rl.WHITE) {
    rl.DrawTextEx(font, text, pos, FONTSIZE, 0, color)
}

render_text_centered :: proc(text: cstring, pos: rl.Vector2, color := rl.WHITE) {
    spacing :: 0
    measure := rl.MeasureTextEx(font, text, FONTSIZE, spacing)
    rl.DrawTextEx(font, text, pos - measure/2, FONTSIZE, spacing, color)
}

get_mouse_layer :: proc(mpos: rl.Vector2, offset := rl.Vector2{0, 0}) -> int {
    mlayer := -1
    layer_y: [4]f32
    {
	layer_y[0] = (number_h + CLOCKSIZE) * 1 + HOUR_RECT_H * 0 + offset.y
	layer_y[1] = (number_h + CLOCKSIZE) * 2 + HOUR_RECT_H * 1 + offset.y
	layer_y[2] = (number_h + CLOCKSIZE) * 3 + HOUR_RECT_H * 2 + offset.y
	layer_y[3] = (number_h + CLOCKSIZE) * 4 + HOUR_RECT_H * 3 + offset.y
    }
    if mpos.y >= layer_y[0] && mpos.y <= layer_y[0] + HOUR_RECT_H {
	mlayer = 0
    } else if mpos.y >= layer_y[1] && mpos.y <= layer_y[1] + HOUR_RECT_H {
	mlayer = 1
    } else if mpos.y >= layer_y[2] && mpos.y <= layer_y[2] + HOUR_RECT_H {
	mlayer = 2
    } else if mpos.y >= layer_y[3] && mpos.y <= layer_y[3] + HOUR_RECT_H {
	mlayer = 3
    }
    return mlayer
}

is_mouse_on_hour_block :: proc(mpos_world_x: f32, mlayer: int) -> bool {
    return (mpos_world_x >= number_w && mpos_world_x <= number_w + layer_w) && mlayer != -1
}
