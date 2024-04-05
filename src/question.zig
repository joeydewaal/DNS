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
        const cname = try string.string_from_bytes(bytes);
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
        std.debug.print("CNAME: {s}\t", .{self.cname.items});
        std.debug.print("QTYPE: {}\n", .{self.QType});
    }

    pub fn write_buffer(self: DnsQuestion, buffer: *Buffer) void {
        if (self.QType == QType.Unsupported) { return; }
        if (self.QClass == QClass.NotSupported) { return; }
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
        return switch (bytes) {
            1 => QType.A,
            2 => QType.NS,
            5 => QType.CNAME,
            6 => QType.SOA,
            12 => QType.PTR,
            15 => QType.MX,
            28 => QType.AAAA,
            else => QType.Unsupported,
        };
    }

    pub fn to_bytes(self: QType) u16 {
        return switch (self) {
            QType.A => 1,
            QType.NS => 2,
            QType.CNAME => 5,
            QType.SOA => 6,
            QType.PTR => 12,
            QType.MX => 15,
            QType.AAAA => 28,
            else => 0
        };
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
