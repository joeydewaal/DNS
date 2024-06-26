const std = @import("std");
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const DnsQuestion = @import("question.zig").DnsQuestion;
const QType = @import("question.zig").QType;
const QClas = @import("question.zig").QClass;
const QClass = @import("question.zig").QClass;
const Buffer = @import("buffer.zig").Buffer;
const string = @import("string.zig");

pub const Record = struct {
    name: string.String,
    type: QType,
    class: QClass,
    ttl: u32,
    r_data: Data,

    pub fn from_bytes(aantal: u16, bytes: *Buffer) !ArrayList(Record) {
        var i: u16 = 0;
        var records = ArrayList(Record).init(allocator.allocator());

        while (i < aantal) {
            i = i + 1;
            const name = try string.string_from_bytes(bytes);
            const dns_type = QType.from_bytes(bytes.read_u16());
            const class = QClass.from_byte(bytes.read_u16());
            const ttl = bytes.read_u32();
            const r_data = try Data.from_bytes(bytes, dns_type);

            try records.append(Record{
                .name = name,
                .type = dns_type,
                .class = class,
                .ttl = ttl,
                .r_data = r_data,
            });
        }
        return records;
    }

    pub fn print(self: *const Record) void {
        std.debug.print("NAME: {s}\t", .{self.name.items});
        std.debug.print("TYPE: {}\t", .{self.type});
        std.debug.print("TTL: {d}s\t", .{self.ttl});
        self.r_data.print();
    }

    pub fn write_buffer(self: *const Record, buffer: *Buffer) void {
        if (self.type == QType.Unsupported) {
            return;
        }
        if (self.class == QClass.NotSupported) {
            return;
        }
        string.write_to_buf(&self.name, buffer);
        buffer.write_u16_to_big(self.type.to_bytes());
        buffer.write_u16_to_big(self.class.to_bytes());
        buffer.write_u32_to_big(self.ttl);
        self.r_data.write_buffer(buffer);
    }
};

pub const Data = struct {
    len: u16,
    data: DataInner,

    fn from_bytes(bytes: *Buffer, data_type: QType) !Data {
        const len = bytes.read_u16();
        switch (data_type) {
            QType.A => {
                const o1 = bytes.read_u8();
                const o2 = bytes.read_u8();
                const o3 = bytes.read_u8();
                const o4 = bytes.read_u8();
                return Data{ .len = len, .data = DataInner{ .A = [4]u8{ o1, o2, o3, o4 } } };
            },
            QType.NS => {
                // idk waarom dit zo moet ma het werkt
                const index = bytes.index;
                const name = try string.string_from_bytes(bytes);
                bytes.set_ptr(index + len);
                return Data{ .len = len, .data = DataInner{ .NS = name } };
            },
            QType.CNAME => {
                const name = try string.string_from_bytes(bytes);
                return Data{ .len = len, .data = DataInner{ .CNAME = name } };
            },
            QType.SOA => {
                return Data{ .len = len, .data = DataInner{ .SOA = .{
                    .mname = try string.string_from_bytes(bytes),
                    .rname = try string.string_from_bytes(bytes),
                    .serial = bytes.read_u32(),
                    .refresh = bytes.read_u32(),
                    .retry = bytes.read_u32(),
                    .expire = bytes.read_u32(),
                } } };
            },
            QType.PTR => {
                return Data{ .len = len, .data = DataInner{ .PTR = try string.string_from_bytes(bytes) } };
            },
            QType.MX => {
                return Data{ .len = len, .data = DataInner{ .MX = .{
                    .preference = bytes.read_u16(),
                    .exchange = try string.string_from_bytes(bytes),
                } } };
            },
            QType.AAAA => {
                const o1 = bytes.read_u16();
                const o2 = bytes.read_u16();
                const o3 = bytes.read_u16();
                const o4 = bytes.read_u16();
                const o5 = bytes.read_u16();
                const o6 = bytes.read_u16();
                const o7 = bytes.read_u16();
                const o8 = bytes.read_u16();

                return Data{ .len = len, .data = DataInner{ .AAAA = [8]u16{ o1, o2, o3, o4, o5, o6, o7, o8 } } };
            },

            else => {
                bytes.move_ptr(len);
                return Data{
                    .len = len,
                    .data = DataInner.Unsupported,
                };
            },
        }
    }

    fn print(self: Data) void {
        self.data.print();
    }

    pub fn write_buffer(self: *const Data, buffer: *Buffer) void {
        switch (self.data) {
            DataInner.A => |ipv4| {
                buffer.write_u16_to_big(4);
                buffer.write_slice(&ipv4);
            },
            DataInner.NS => |ns| {
                var strlen = string.strlen(&ns);
                buffer.write_u16_to_big(strlen);
                string.write_to_buf(&ns, buffer);
            },
            DataInner.CNAME => |cname| {
                var strlen = string.strlen(&cname);
                buffer.write_u16_to_big(strlen);
                string.write_to_buf(&cname, buffer);
            },
            DataInner.SOA => |soa| {
                const strlen1 = string.strlen(&soa.mname);
                const strlen2 = string.strlen(&soa.rname);

                buffer.write_u16_to_big(strlen1 + strlen2 + 16);

                string.write_to_buf(&soa.mname, buffer);
                string.write_to_buf(&soa.rname, buffer);

                buffer.write_u32_to_big(soa.serial);
                buffer.write_u32_to_big(soa.refresh);
                buffer.write_u32_to_big(soa.retry);
                buffer.write_u32_to_big(soa.expire);
            },
            DataInner.PTR => |ptr| {
                const strlen = string.strlen(&ptr);
                buffer.write_u16_to_big(strlen);
                string.write_to_buf(&ptr, buffer);
            },
            DataInner.MX => |mx| {
                const strlen = string.strlen(&mx.exchange);
                buffer.write_u16_to_big(strlen + 2);

                buffer.write_u16_to_big(mx.preference);
                string.write_to_buf(&mx.exchange, buffer);
            },
            DataInner.AAAA => |ipv6| {
                buffer.write_u16_to_big(16);
                buffer.write_slice_u16(&ipv6);
            },
            else => {
                buffer.move_ptr(self.len);
            },
        }
    }
};

pub const DataInner = union(QType) {
    A: [4]u8,
    NS: string.String,
    CNAME: string.String,
    SOA: struct {
        mname: string.String,
        rname: string.String,
        serial: u32,
        refresh: u32,
        retry: u32,
        expire: u32,
    },
    PTR: string.String,
    MX: struct {
        preference: u16,
        exchange: string.String,
    },
    AAAA: [8]u16,
    Unsupported,

    pub fn print(self: DataInner) void {
        switch (self) {
            DataInner.A => |ip| {
                std.debug.print("ipv4: {d}.{d}.{d}.{d}\n", .{ ip[0], ip[1], ip[2], ip[3] });
            },
            DataInner.NS => |ns| {
                std.debug.print("NS: {s}\n", .{ns.items});
            },
            DataInner.CNAME => |cname| {
                std.debug.print("CNAME: {s}\n", .{cname.items});
            },
            DataInner.SOA => |soa| {
                std.debug.print("SOA:\tmname:   {s}\n", .{soa.mname.items});
                std.debug.print("\t\trname:   {s}\n", .{soa.rname.items});
                std.debug.print("\t\tserial:  {d}\n", .{soa.serial});
                std.debug.print("\t\trefresh: {d}\n", .{soa.refresh});
                std.debug.print("\t\tretry    {d}\n", .{soa.retry});
                std.debug.print("\t\texpire:  {d}\n", .{soa.expire});
            },
            DataInner.PTR => |ptr| {
                std.debug.print("PTR: {s}", .{ptr.items});
            },
            DataInner.MX => |mx| {
                std.debug.print("MX\texchange:   {s}\n", .{mx.exchange.items});
                std.debug.print("\t\tpreference: {d}\n", .{mx.preference});
            },
            DataInner.AAAA => |ip| {
                std.debug.print("ipv6: {x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}:{x:0>2}::{x:0>2}\n", .{ ip[0], ip[1], ip[2], ip[3], ip[4], ip[5], ip[6], ip[7] });
            },
            else => |_| std.debug.print("UNSSUPORTED QTYPE\n", .{}),
        }
    }
};
