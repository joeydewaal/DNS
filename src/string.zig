const std = @import("std");

pub const Label = []u8;
pub const String = std.ArrayList(Label);
const Buffer = @import("buffer.zig").Buffer;

var allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn string_from_bytes(buffer: *Buffer) !String {
    var string = String.init(allocator.allocator());
    var jumped: bool = false;

    var verste_index = buffer.get_index();
    // std.debug.print("start i: {d}\n", .{verste_index});

    var times_jumped: u16 = 0;

    var index: u16 = buffer.index;
    std.debug.print("index: {d}\n", .{buffer.index});

    while (true) {
        var len = buffer.read_at(index);
        std.debug.print("READ len i: {d}\n", .{index});

        if (times_jumped > 6) {
            @panic("Te veel gejumped");
        }

        if (len == 0) {
            std.debug.print("End of string i: {d}\n", .{index});
            if (!jumped) {
                verste_index = verste_index + 1;
            }
            break;
        } else if (len >> 5 != 0) {
            var ptr: u16 = @intCast(len & 63);
            ptr = ptr << 8 | buffer.read_at(index + 1);

            // verste_index = buffer.get_index();

            std.debug.print("FOUND PTR p: {d} i: {d}\n", .{ ptr, index });

            index = ptr;
            times_jumped = times_jumped + 1;
            // buffer.set_ptr(ptr);

            if (!jumped) {
                buffer.move_ptr(2);
            }

            // len = buffer.read_u8();
            jumped = true;
            continue;
        }

        std.debug.print("ADDING STR i: {d}-{d}\n", .{ index, len });
        index = index + 1;
        const l = buffer.read_range(index, index + len);
        std.debug.print("label: {s}\n", .{l});
        index = index + len;

        try string.append(l);
    }
    if (!jumped) {
        buffer.set_ptr(index + 1);
    }
    std.debug.print("reseting i: {d}\n", .{buffer.index});
    return string;
}

pub fn write_to_buf(string: *const String, buffer: *Buffer) void {
    for (string.items) |label| {
        buffer.write_u8(@intCast(label.len));
        buffer.write_slice(label);
    }
    buffer.write_u8(0);
}
