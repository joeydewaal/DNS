const std = @import("std");
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const DnsQuestion = @import("question.zig").DnsQuestion;
const QType = @import("question.zig").QType;
const QClass = @import("question.zig").QClass;
const Buffer = @import("buffer.zig").Buffer;
const string = @import("string.zig");
const Ipv4Address = std.net.Ip4Address;

pub const Record = struct {
    name: string.String,
    type: Type,
    class_code: u16,
    ttl: u32,
    rd_length: u16,
    r_data: Data,

    pub fn from_bytes(aantal: u16, bytes: *Buffer) !ArrayList(Record) {
        var i: u16 = 0;

        var records = ArrayList(Record).init(allocator.allocator());

        while (i < aantal) {
            i = i + 1;
            // std.debug.print("{d}\n", .{aantal});
            const name = try string.string_from_bytes(bytes);
            // std.debug.print("- {d}\n", .{bytes.index});
            const r_type = Type.from_bytes(bytes.read_u16());
            const class = bytes.read_u16();
            // const class2 = bytes.read_u16();
            // _ = class2;
            // _ = class2;

            const ttl = bytes.read_u16();
            const rd_length = bytes.read_u16();

            // std.debug.print("r data: {d}\n", .{rd_length});

            const r_data = Data.from_bytes(bytes, r_type);

            try records.append(Record{
                .name = name,
                .type = r_type,
                .class_code = class,
                .ttl = ttl,
                .rd_length = rd_length,
                .r_data = r_data,
            });
        }

        // std.debug.print("{any}\n", .{records.items});

        return records;
    }
};

pub const Type = enum {
    A,
    CNAME,
    Unsupported,

    fn from_bytes(bytes: u16) Type {
        switch (bytes) {
            1 => return Type.A,
            5 => return Type.CNAME,
            else => return Type.Unsupported,
        }
    }
};

pub const Data = union {
    A: Ipv4Address,
    Unsupported: i8,

    fn from_bytes(bytes: *Buffer, data_type: Type) Data {
        switch (data_type) {
            Type.A => {
                const o1 = bytes.read_u8();
                const o2 = bytes.read_u8();
                const o3 = bytes.read_u8();
                const o4 = bytes.read_u8();
                std.debug.print("{d}.{d}.{d}.{d}\n", .{o1, o2, o3, o4});
                return Data{.A= Ipv4Address.init([4]u8{ o1, o2,o3,o4}, 0)};
            },
            Type.CNAME => {
                return Data{ .Unsupported = 0};
            },
            else => {
                return Data{ .Unsupported = 0 };
            }
        }
    }
};
