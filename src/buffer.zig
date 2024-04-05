pub const MAX_BUFF = 1024;
const std = @import("std");

pub const Buffer = struct {
    index: u16,
    buffer: [MAX_BUFF]u8,

    pub fn print_last_index(self: *Buffer) void {
        std.debug.print("{d}\n", .{self.index - 1});
    }

    pub fn from_bytes(bytes: []u8) Buffer {
        var buffer = Buffer.new_empty();
        @memcpy(buffer.buffer[0..bytes.len], bytes);
        return buffer;
    }

    pub fn new_empty() Buffer {
        return Buffer{
            .index = 0,
            .buffer = std.mem.zeroes([MAX_BUFF]u8)
        };
    }

    pub fn slice_to_end(self: *Buffer) []u8 {
        return self.buffer[self.index..];
    }

    pub fn slice_from_start(self: * const Buffer) []const u8 {
        return self.buffer[0..self.index];
    }

    pub fn read_u16(self: *Buffer) u16 {
        const data = std.mem.readIntSliceBig(u16, self.buffer[self.index .. self.index + 2]);
        self.index = self.index + 2;
        return data;
    }

    pub fn read_u32(self: *Buffer) u32 {
        const data = std.mem.readIntSliceBig(u32, self.buffer[self.index .. self.index + 4]);
        self.index = self.index + 4;
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
        self.index = self.index + i;
    }

    pub fn set_ptr(self: *Buffer, i: u16) void {
        self.index = i;
    }

    pub fn read_at(self: *Buffer, i: u16) u8 {
        return self.buffer[i];
    }

    pub fn write_u8(self: *Buffer, data: u8) void {
        self.buffer[self.index] = data;
        self.index = self.index + 1;
    }

    pub fn write_u16_to_big(self: *Buffer, data: u16) void {
        self.write_u16(std.mem.nativeToBig(u16, data));
    }

    pub fn write_u32_to_big(self: *Buffer, data: u32) void {
        self.write_u32(std.mem.nativeToBig(u32, data));
    }


    pub fn write_u16(self: *Buffer, data: u16) void {
        var result: [2]u8 = @bitCast(data);
        @memcpy(self.buffer[self.index .. self.index + 2], &result);
        self.index = self.index + 2;
    }

    pub fn write_u32(self: *Buffer, data: u32) void {
        var result: [4]u8 = @bitCast(data);
        @memcpy(self.buffer[self.index .. self.index + 4], &result);
        self.index = self.index + 4;
    }

    pub fn write_slice(self: *Buffer, data: [] const u8 ) void {
        @memcpy(self.buffer[self.index..self.index + data.len], data);
        const len:u16 = @intCast(data.len);
        self.index = self.index + len;
    }

    pub fn write_slice_u16(self: *Buffer, data: [] const u16 ) void {
        for (data) |bytes| {
            self.write_u16(bytes);
        }
    }
};
