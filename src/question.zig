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

        const q_type = bytes.read_u16();
        _ = bytes.read_u16(); // q_class

        return DnsQuestion{
            .cname = cname,
            .QType = QType.from_bytes(q_type),
            .QClass = QClass.InternetAdress,
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
};

pub const QType = enum {
    Reserved,
    A,
    NS,
    MD,
    MF,
    CNAME,
    SOA,
    Unimplemented,

    pub fn from_bytes(bytes: u16) QType {
        switch (bytes) {
            0 => return QType.Reserved,
            1 => return QType.A,
            2 => return QType.NS,
            3 => return QType.MD,
            4 => return QType.MF,
            else => return QType.Unimplemented,
        }
    }
};

pub const QClass = enum { InternetAdress };
