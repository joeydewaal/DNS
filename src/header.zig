const std = @import("std");
const DnsQuestion = @import("question.zig").DnsQuestion;
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const Record = @import("record.zig").Record;
const Buffer = @import("buffer.zig").Buffer;
const DnsPacket = @import("packet.zig").DnsPacket;
const QType = @import("question.zig").QType;
const QClass = @import("question.zig").QClass;

const HeaderInner = packed struct(u16) {
    qr: u1,
    op_code: u4,
    AA: u1,
    TC: u1,
    RD: u1,
    RA: u1,
    Z: u3 = 0,
    RCODE: u4,

    fn from_bytes(bytes: u16) HeaderInner {
        return HeaderInner{
            .qr = @intCast((bytes >> 15) & 1),
            .op_code = @intCast((bytes >> 11) & 15),
            .AA = @intCast((bytes >> 10) & 1),
            .TC = @intCast((bytes >> 9) & 1),
            .RD = @intCast((bytes >> 8) & 1),
            .RA = @intCast((bytes >> 7) & 1),
            .RCODE = @intCast((bytes & 15))
        };
    }

    pub inline fn write_buffer(self: *const HeaderInner, buffer: *Buffer) void {
        // const header: u16 = std.mem.readIntBig(u16, std.mem.asBytes(self));

        var bytes: u16 = 0;
        const qr: u16 = @intCast(self.qr);
        bytes = bytes | qr << 15;

        const op_code:u16 = @intCast(self.op_code);
        bytes = bytes | op_code << 11;

        const AA:u16 = @intCast(self.AA);
        bytes = bytes | AA << 10;

        const TC:u16 = @intCast(self.TC);
        bytes = bytes | TC << 9;

        const RD:u16 = @intCast(self.RD);
        bytes = bytes | RD << 8;

        const RA:u16 = @intCast(self.RA);
        bytes = bytes | RA << 7;

        bytes = bytes | self.RCODE;
        buffer.write_u16_to_big(bytes);
    }
};

pub const Header = struct {
    id: u16,
    header_inner: HeaderInner,
    /// aantal vragen
    qd_count: u16,
    /// aantal resource records
    an_count: u16,
    /// aantal name server records
    ns_count: u16,
    /// aantal additional records
    ar_count: u16,

    pub fn from_bytes(bytes: *Buffer) !Header {
        const id = bytes.read_u16();
        const header_inner = HeaderInner.from_bytes(bytes.read_u16());

        const qd_count = bytes.read_u16();
        const an_count = bytes.read_u16();
        const ns_count = bytes.read_u16();
        const ar_count = bytes.read_u16();

        return Header{
            .id = id,
            .header_inner = header_inner,
            .qd_count = qd_count,
            .an_count = an_count,
            .ns_count = ns_count,
            .ar_count = ar_count,
        };
    }

    pub inline fn is_query(self: Header) bool {
        return self.header_inner.qr == 0;
    }
    pub inline fn get_op_code(self: Header) OPCode {
        return OPCode.from_byte(@intCast(self.header_inner.op_code));
    }
    pub inline fn is_authoritive_answer(self: Header) bool {
        return self.header_inner.AA == 1;
    }
    pub inline fn is_truncated(self: Header) bool {
        return self.header_inner.TC == 1;
    }
    pub inline fn recursion_desired(self: Header) bool {
        return self.header_inner.RD == 1;
    }
    pub inline fn set_recursion_desired( self: * Header , is_desired: bool) void {
        self.header_inner.RD = @intFromBool(is_desired);
    }

    pub inline fn recursion_available(self: Header) bool {
        return self.header_inner.RA == 1;
    }
    pub inline fn get_rcode(self: Header) RCODE {
        return RCODE.from_byte(@intCast(self.header_inner.RCODE));
    }


    pub fn write_buffer(self: *const  Header, buffer: *Buffer) void {
        buffer.write_u16_to_big(self.id);
        self.header_inner.write_buffer(buffer);
        buffer.write_u16_to_big(self.qd_count);
        buffer.write_u16_to_big(self.an_count);
        buffer.write_u16_to_big(self.ns_count);
        buffer.write_u16_to_big(self.ar_count);
    }

    pub fn print(self: *const Header) void {
        std.debug.print("ID: {d}\t", .{self.id});
        std.debug.print("QR: {}\t", .{self.is_query()});
        std.debug.print("OP CODE: {}\t", .{self.get_op_code()});

        std.debug.print("AA: {}\t", .{self.is_authoritive_answer()});
        std.debug.print("TC: {}\t", .{self.is_truncated()});
        std.debug.print("RD: {}\t", .{self.recursion_desired()});
        std.debug.print("RA: {}\n", .{self.recursion_available()});

        std.debug.print("Q count: {d}\t", .{self.qd_count});
        std.debug.print("AN count: {d}\t", .{self.an_count});
        std.debug.print("N count: {d}\t", .{self.ns_count});
        std.debug.print("AR count: {d}\t", .{self.ar_count});
        std.debug.print("RCODE: {}\n", .{self.get_rcode()});
    }
};

const RCODE = enum {
    NoError,
    FormErr,
    ServFail,
    NXDomain,
    NotImp,
    Refused,
    Unassigned,
    Reserved,

    pub fn from_byte(byte: u8) RCODE {
        const result = switch (byte) {
            0 => RCODE.NoError,
            1 => RCODE.FormErr,
            2 => RCODE.ServFail,
            3 => RCODE.NXDomain,
            4 => RCODE.NotImp,
            5 => RCODE.Refused,
            else => RCODE.Unassigned,
        };
        return result;
    }

    pub fn print(self: *const RCODE) void {
        std.debug.print("RCode:\t{}\n", .{self});
    }
};

const QR = enum {
    QUERY,
    REPLY,

    pub fn from_byte(byte: u8) QR {
        switch (byte) {
            0 => return QR.QUERY,
            else => return QR.REPLY,
        }
    }
};

const OPCode = enum(u4) {
    QUERY,
    IQUERY,
    STATUS,
    UNASSIGNED,

    pub fn from_byte(byte: u8) OPCode {
        switch (byte) {
            0 => return OPCode.QUERY,
            1 => return OPCode.IQUERY,
            2 => return OPCode.STATUS,
            else => return OPCode.UNASSIGNED,
        }
    }
};
