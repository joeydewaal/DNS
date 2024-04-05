const std = @import("std");

pub const Label = []u8;
pub const String = std.ArrayList(Label);
const Buffer = @import("buffer.zig").Buffer;

var allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn string_from_bytes(buffer: *Buffer) !String {
    var string = String.init(allocator.allocator());
    var jumped: bool = false;

    var times_jumped: u16 = 0;

    var index: u16 = buffer.index;

    while (true) {
        var len = buffer.read_at(index);

        if (times_jumped > 6) {
            @panic("Te veel gejumped");
        }

        if (len == 0) {
            break;
        } else if (len >> 5 != 0) {
            var ptr: u16 = @intCast(len & 63);
            ptr = ptr << 8 | buffer.read_at(index + 1);

            index = ptr;
            times_jumped = times_jumped + 1;

            if (!jumped) {
                buffer.move_ptr(2);
            }

            jumped = true;
            continue;
        }
        index = index + 1;
        const l = buffer.read_range(index, index + len);
        index = index + len;

        try string.append(l);
    }
    if (!jumped) {
        buffer.set_ptr(index + 1);
    }
    return string;
}

pub fn write_to_buf(string: *const String, buffer: *Buffer) void {
    for (string.items) |label| {
        buffer.write_u8(@intCast(label.len));
        buffer.write_slice(label);
    }
    buffer.write_u8(0);
}

pub fn strlen(string: *const String) u16 {
    // +1 voor null char
    var str_len: usize = string.items.len + 1;
    for (string.items) |label| {
        str_len = str_len + label.len;
    }
    return @intCast(str_len);
}

pub fn eq(string1: * String, string2: * String) bool {
    if (string1.items.len != string2.items.len) {
        return false;
    }

    for (string1.items, string2.items) |label1, label2| {
        if (!std.mem.eql( u8, label1, label2)){
            return false;
        }
    }
    return true;
}

pub fn ends_with(string1: *const String, string2: *const String) bool {
    var last_label1: usize = string1.items.len - 1;
    var last_label2: usize = string2.items.len - 1;

    while (true) {

        if (!std.mem.eql( u8, string1.items[last_label1], string2.items[last_label2])){
            return false;
        }
        if (last_label2 != 0){
            break;
        }
        last_label1 = last_label1 - 1;
        last_label2 = last_label2 - 1;
    }
    return true;
}
