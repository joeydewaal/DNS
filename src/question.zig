const std = @import("std");
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const Label = []u8;
const Buffer = @import("buffer.zig").Buffer;
const string = @import("string.zig");

const ArrayList = std.ArrayList;

pub const DnsQuestion = struct {
    cname: string.String,
    QType: QType,
    QClass: QClass,

    pub fn from_bytes(bytes: *Buffer) !DnsQuestion {
        std.debug.print("DNSQ : read string\n", .{});
        const cname = try string.string_from_bytes(bytes);
            var index: u16 = 0;
            for (bytes.buffer) |b| {
                std.debug.print("i: {d} v:{x}\n", .{index,b});
                index = index + 1;
            }
            std.debug.print("\n", .{});

        const q_type = QType.from_bytes(bytes.read_u16());
        const class = QClass.from_byte(bytes.read_u16());

        return DnsQuestion{
            .cname = cname,
            .QType = q_type,
            .QClass = class,
        };
    }
    pub fn all_from_bytes(count: u16, bytes: *Buffer) !ArrayList(DnsQuestion) {
        var questions = ArrayList(DnsQuestion).init(allocator.allocator());
        var i: u16 = 0;
        while (i < count) {
            i = i + 1;

            const question = try DnsQuestion.from_bytes(bytes);
            try questions.append(question);
        }
        return questions;
    }

    pub fn print(self: *const DnsQuestion) void {
        std.debug.print("CNAME:\t{s}\n", .{self.cname.items});
        std.debug.print("QTYPE:\t{}\n", .{self.QType});
    }

    pub fn write_buffer(self: DnsQuestion, buffer: *Buffer) void {
        string.write_to_buf(&self.cname, buffer);
        buffer.write_u16_to_big(self.QType.to_bytes());
        buffer.write_u16_to_big(self.QClass.to_bytes());
    }
};

pub const QType = enum(u16) {
    A = 1,
    NS = 2,
    CNAME = 5,
    SOA = 6,
    PTR = 12,
    MX = 15,
    AAAA = 28,
    Unsupported = 0,

    pub fn from_bytes(bytes: u16) QType {
        std.debug.print("QTYPE: {d}\n", .{bytes});
        return @enumFromInt(bytes);
    }

    pub fn to_bytes(self: QType) u16 {
        return @intFromEnum(self);
    }
};

pub const QClass = union(enum) {
    NotSupported: u16,
    InternetAdress,

    pub fn from_byte(bytes: u16) QClass {
        switch (bytes) {
            1 => return QClass.InternetAdress,
            else => return QClass{ .NotSupported = bytes },
        }
    }

    pub fn to_bytes(self: QClass) u16 {
        switch (self) {
            QClass.NotSupported => |bytes| return bytes,
            QClass.InternetAdress => |_| return 1,
        }
    }
};
