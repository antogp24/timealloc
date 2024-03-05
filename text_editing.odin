package main

import "core:fmt"
import rl "vendor:raylib"

// Text editing for single line buffers.

buf_register_typing :: proc(cursor: ^int, buf: ^[dynamic]u8, chr: u8) {
    holding_modifiers := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.LEFT_CONTROL)

    if (chr >= ' ' && chr <= '~') && !holding_modifiers {
	inject_at(buf, cursor^, chr)
	cursor^ += 1
    }
}

buf_move_left :: proc(cursor: ^int) {
    cursor^ -= 1
    cursor^ = max(cursor^, 0)
}

buf_move_right :: proc(cursor: ^int, buf: [dynamic]u8) {
    cursor^ += 1
    cursor^ = min(cursor^, len(buf) - 1)
}

buf_backspace :: proc(cursor: ^int, buf: ^[dynamic]u8) {
    cursor^ -= 1
    cursor^ = max(cursor^, 0)
    if buf^[cursor^] != 0 {
	ordered_remove(buf, cursor^)
    }
}

buf_goto_start :: proc(cursor: ^int) {
    cursor^ = 0
}

buf_goto_end :: proc(cursor: ^int, buf: [dynamic]u8) {
    cursor^ = len(buf) - 1
}

buf_move_left_by_word :: proc(cursor: ^int, buf: [dynamic]u8) {
    for cursor^ > 0 && len(buf) > 0 {
	buf_move_left(cursor)
	if cursor^ == 0 do break
	c := buf[cursor^ - 1] 
	if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
	    break
	}
    }
} 

buf_move_right_by_word :: proc(cursor: ^int, buf: [dynamic]u8) {
    for {
	buf_move_right(cursor, buf)
	if cursor^ == len(buf) - 1 do break
	c := buf[cursor^]
	if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
	    break
	}
    }
}

buf_backspace_by_word :: proc(cursor: ^int, buf: ^[dynamic]u8) {
    for cursor^ > 0 && len(buf^) > 0 {
	if len(buf^) > 0 {
	    cursor^ -= 1
	    cursor^ = max(cursor^, 0)
	    if buf^[cursor^] != 0 {
		ordered_remove(buf, cursor^)
	    }
	}
	if cursor^ == 0 do break
	c := buf^[cursor^ - 1]
	if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
	    break
	}
    }
}
