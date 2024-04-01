const MAX_BUFF = 512;
const std = @import("std");

pub const Buffer = struct {
    index: u16,
    buffer: [MAX_BUFF]u8,

    pub fn from_bytes(bytes: []u8) Buffer {
        var buffer = Buffer{ .index = 0, .buffer = std.mem.zeroes([MAX_BUFF]u8) };
        @memcpy(buffer.buffer[0..bytes.len], bytes);
        return buffer;
    }

    pub fn read_u16(self: *Buffer) u16 {
        const data = std.mem.readIntSliceBig(u16, self.buffer[self.index .. self.index + 2]);
        self.index = self.index + 2;
        return data;
    }

    pub fn read_u8(self: *Buffer) u8 {
        const data = self.buffer[self.index];
        self.index = self.index + 1;
        return data;
    }

    pub fn read_range(self: *Buffer, start: u16, end: u16) []u8 {
        return self.buffer[start.. end];
    }

    pub fn read_n_bytes(self: *Buffer, count: u16) []u8 {
        const data = self.buffer[self.index .. self.index + count];
        self.index = self.index + count;
        return data;
    }

    pub fn get_index(self: *Buffer) u16 {
        return self.index;
    }

    pub fn move_ptr(self: *Buffer, i: u16) void {
        self.index = i;
    }

    pub fn read_at(self: *Buffer, i: u16) u8 {
        return self.buffer[i];
    }
};
