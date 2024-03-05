package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// Text editing for single line buffers.

TextBox :: struct {
    text: strings.Builder,
    cursor: int,
}


buf_register_typing_numbers :: proc(using t: ^TextBox, chr: u8, limit := -1) {
    holding_modifiers := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.LEFT_CONTROL)

    if (chr >= '0' && chr <= '9') && !holding_modifiers {
	if limit == -1 {
	    inject_at(&text.buf, cursor, chr)
	} else if len(text.buf) + 1 <= limit {
	    inject_at(&text.buf, cursor, chr)
	}
	cursor += 1
    }
    if limit != -1 do cursor = min(cursor, limit)
}

buf_register_typing :: proc(using t: ^TextBox, chr: u8) {
    holding_modifiers := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.LEFT_CONTROL)

    if (chr >= ' ' && chr <= '~') && !holding_modifiers {
	inject_at(&text.buf, cursor, chr)
	cursor += 1
    }
}

buf_move_left :: proc(using t: ^TextBox) {
    cursor -= 1
    cursor = max(cursor, 0)
}

buf_move_right :: proc(using t: ^TextBox) {
    cursor += 1
    cursor = min(cursor, len(text.buf) - 1)
}

buf_backspace :: proc(using t: ^TextBox) {
    cursor -= 1
    cursor = max(cursor, 0)
    if text.buf[cursor] != 0 {
	ordered_remove(&text.buf, cursor)
    }
}

buf_goto_start :: proc(using t: ^TextBox) {
    cursor = 0
}

buf_goto_end :: proc(using t: ^TextBox) {
    cursor = len(text.buf) - 1
}

buf_move_left_by_word :: proc(using t: ^TextBox) {
    for cursor > 0 && len(text.buf) > 0 {
	buf_move_left(t)
	if cursor == 0 do break
	c := text.buf[cursor - 1] 
	if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
	    break
	}
    }
} 

buf_move_right_by_word :: proc(using t: ^TextBox) {
    for {
	buf_move_right(t)
	if cursor == len(text.buf) - 1 do break
	c := text.buf[cursor]
	if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
	    break
	}
    }
}

buf_backspace_by_word :: proc(using t: ^TextBox) {
    for cursor > 0 && len(text.buf) > 0 {
	if len(text.buf) > 0 do buf_backspace(t)
	if cursor == 0 do break
	c := text.buf[cursor - 1]
	if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
	    break
	}
    }
}
