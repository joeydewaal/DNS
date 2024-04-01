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

    while (true) {
        var len = buffer.read_u8();

        if (len == 0) {
            // std.debug.print("End of string\n", .{});
            if (!jumped) {
                verste_index = verste_index + 1;
            }

            break;
        } else if (len >> 5 != 0) {
            var ptr: u16 = @intCast(len & 63);
            ptr = ptr << 8 | buffer.read_u8();

            // std.debug.print("PTR {d}\n", .{ptr});

            verste_index = buffer.get_index() + 2;

            buffer.move_ptr(ptr);

            len = buffer.read_u8();
            jumped = true;
        }
        try string.append(buffer.read_n_bytes(len));
        if (!jumped) {
            verste_index = buffer.get_index();
        }
    }
    // std.debug.print("parsed str: {s}\n", .{string.items});
    // std.debug.print("eind i: {d}\n\n", .{verste_index});
    buffer.index = verste_index;
    return string;
}
