package main

import "core:fmt"
import "core:mem"
import "core:os"

// Saving and loading all the timeblocks to and from a stream of bytes.
// Credits to John Jackson for an awesome video of how to do binary serialization in C.
// https://www.youtube.com/watch?v=GXdT8twQxxI&ab_channel=JohnJackson

BYTE_BUFFER_DEFAULT_CAP :: 1024

// Generic byte buffer to serialize data.
ByteBuffer :: struct {
    position, size, capacity: int,
    data: rawptr,
}

byte_buffer_new :: proc() -> (buffer: ByteBuffer) {
    buffer.data, _ = mem.alloc(BYTE_BUFFER_DEFAULT_CAP * size_of(u8), allocator=context.temp_allocator)
    buffer.capacity = BYTE_BUFFER_DEFAULT_CAP
    return buffer
}

byte_buffer_resize :: proc(using buffer: ^ByteBuffer, new_capacity: int) {
    free_all(context.temp_allocator)
    data, _ = mem.alloc(new_capacity * size_of(u8), allocator=context.temp_allocator)
}

byte_buffer_write :: proc(using buffer: ^ByteBuffer, $T: typeid, value_ptr: ^T) {
    total_write_size := position + size_of(T)

    if total_write_size >= capacity {
        capacity := capacity * 2 if capacity != 0 else BYTE_BUFFER_DEFAULT_CAP
        for capacity < total_write_size do capacity *= 2
        byte_buffer_resize(buffer, capacity)
    }
    dest := uintptr(data) + uintptr(position)
    mem.copy(rawptr(dest), value_ptr, size_of(T))
    position += size_of(T)
    size += size_of(T)
}

byte_buffer_read :: proc(using buffer: ^ByteBuffer, $T: typeid, value_ptr: ^T) {
    ptr := cast(^T)(uintptr(data) + uintptr(position))
    value_ptr^ = ptr^
    position += size_of(T)
}

byte_buffer_write_to_file :: proc(using buffer: ^ByteBuffer, filename: string) {
    file, _ := os.open(filename, os.O_WRONLY)
    os.write_ptr(file, data, size)
    os.ftruncate(file, i64(size))
    os.close(file)
}

byte_buffer_read_from_file :: proc(using buffer: ^ByteBuffer, filename: string) -> (success: bool) {
    file_data, ok := os.read_entire_file(filename, context.temp_allocator)
    if !ok do return false

    data = raw_data(file_data)
    size = len(file_data)
    capacity = len(file_data)
    return true
}

// timeblocks [N_LAYERS][dynamic]TimeBlock   To be serialized

// TimeBlock :: struct
//     start:    f32                size_of(f32)
//     duration: f32                size_of(f32)
//     using textbox: TextBox

// TextBox :: struct
//     cursor: int                  size_of(int)
//     text:   strings.Builder

// strings.Builder :: struct
//      buf: [dynamic]u8            size_of(u8) * len(buf)

SAVE_FILE_NAME :: "user.timealloc"

serialize_save :: proc() -> (bytes_saved: int) {
    buffer := byte_buffer_new()
    defer free_all(context.temp_allocator)

    for layer in 0..<N_LAYERS {
        // Writing the amount of timeblocks.
        timeblocks_count := len(timeblocks[layer])
        byte_buffer_write(&buffer, int, &timeblocks_count)

        for block in 0..<timeblocks_count {
            // Writing the contents of the timeblock.
            byte_buffer_write(&buffer, f32, &timeblocks[layer][block].start)
            byte_buffer_write(&buffer, f32, &timeblocks[layer][block].duration)
            byte_buffer_write(&buffer, int, &timeblocks[layer][block].cursor)

            // Writing the amount of characters.
            characters_count := len(timeblocks[layer][block].text.buf)
            byte_buffer_write(&buffer, int, &characters_count)

            // Writing the contents of the text
            for character in 0..<characters_count {
                byte_buffer_write(&buffer, u8, &timeblocks[layer][block].text.buf[character])
            }
        }
    }

    byte_buffer_write_to_file(&buffer, SAVE_FILE_NAME)

    return buffer.size
}

LoadResult :: enum {
    CREATED_SAVE_FILE,
    SKIPPED_SAVE_FILE,
    NO_BLOCKS_TO_LOAD,
    SUCCESS,
}

serialize_load :: proc() -> (load_result: LoadResult, bytes_loaded: int) {
    buffer := byte_buffer_new()
    defer free_all(context.temp_allocator)

    read_success := byte_buffer_read_from_file(&buffer, SAVE_FILE_NAME)

    // Create the file in case it doesn't exist.
    if !read_success {
        file, _ := os.open(SAVE_FILE_NAME, os.O_CREATE)
        os.close(file)
        return .CREATED_SAVE_FILE, 0
    }

    // Check that the file isn't empty.
    if buffer.size == 0 {
        return .SKIPPED_SAVE_FILE, 0
    }

    for layer in 0..<N_LAYERS {
        // Reading the amount of timeblocks.
        timeblocks_count: int
        byte_buffer_read(&buffer, int, &timeblocks_count)

        for block in 0..<timeblocks_count {
            // Reading the contents of the timeblock.
            start, duration: f32; cursor: int
            byte_buffer_read(&buffer, f32, &start)
            byte_buffer_read(&buffer, f32, &duration)
            byte_buffer_read(&buffer, int, &cursor)

            // Reconstructing part of the struct.
            timeblock: TimeBlock
            timeblock.start = start
            timeblock.duration = duration
            timeblock.cursor = cursor

            // Reading the amount of characters.
            characters_count: int
            byte_buffer_read(&buffer, int, &characters_count)

            // Reading the contents of the text
            for character in 0..<characters_count {
                chr: u8
                byte_buffer_read(&buffer, u8, &chr)
                append(&timeblock.text.buf, chr)
            }
            append(&timeblocks[layer], timeblock)
        }
    }

    if buffer.size == N_LAYERS * size_of(int) {
        return .NO_BLOCKS_TO_LOAD, buffer.size
    }

    return .SUCCESS, buffer.size
}

AUTO_SAVE :: #config(AUTO_SAVE, true)

when ODIN_DEBUG {

    serialize_load_and_log :: proc() {
        load_result, bytes_loaded := serialize_load()
        switch load_result {
        case .SUCCESS: 
            fmt.printf("[TIMEALLOC:INFO] Loading was sucessfull with %v bytes loaded.\n", bytes_loaded)
        case .NO_BLOCKS_TO_LOAD: 
            fmt.println("[TIMEALLOC:INFO] Loading was sucessfull, as there were no blocks to load.")
        case .CREATED_SAVE_FILE:
            fmt.println("[TIMEALLOC:INFO] Loading was not sucessfull, created a new file.")
        case .SKIPPED_SAVE_FILE:
            fmt.println("[TIMEALLOC:INFO] Loading was not sucessfull, skipped the file as it was empty.")
        }
    }

    serialize_save_and_log :: proc() {
        bytes_saved := serialize_save()
        fmt.printf("[TIMEALLOC:INFO] Saving was sucessfull with %v bytes saved.\n", bytes_saved)
    }

} else {
    serialize_load_and_log :: serialize_load
    serialize_save_and_log :: serialize_save
}
