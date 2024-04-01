const std = @import("std");
const DnsQuestion = @import("question.zig").DnsQuestion;
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const Record = @import("record.zig").Record;
const Buffer = @import("buffer.zig").Buffer;

pub const Header = struct {
    id: u16,
    qr: QR,
    op_code: OPCode,
    AA: bool,
    TC: bool,
    RD: bool,
    RA: bool,
    Z: u3,
    RCODE: RCODE,

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

        const byte = bytes.read_u8();
        const qr = QR.from_byte(byte & (1 << 7));
        const op_code = OPCode.from_byte((byte >> 3) & 15);
        const author_answer = byte & (1 << 2) != 0;
        const truncation = byte & (1 << 1) != 0;
        const recursion_desired = byte & 1 != 0;

        const next_byte = bytes.read_u8();
        const recursion_available = next_byte & (1 << 7) != 0;
        const r_code = RCODE.from_byte(next_byte & 15);

        const qd_count = bytes.read_u16();
        const an_count = bytes.read_u16();
        const ns_count = bytes.read_u16();
        const ar_count = bytes.read_u16();

        std.debug.print("qd: {d}\n", .{qd_count});
        std.debug.print("an: {d}\n", .{an_count});
        std.debug.print("ns: {d}\n", .{ns_count});
        std.debug.print("ar: {d}\n", .{ar_count});

        return Header{
            .id = id,
            .qr = qr,
            .op_code = op_code,
            .AA = author_answer,
            .TC = truncation,
            .RD = recursion_desired,
            .RA = recursion_available,
            .Z = 0,
            .RCODE = r_code,
            .qd_count = qd_count,
            .an_count = an_count,
            .ns_count = ns_count,
            .ar_count = ar_count,
        };
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

const OPCode = enum {
    QUERY,
    IQUERY,
    STATUS,
    NOTIFY,
    UPDATE,
    DSO,
    UNASSIGNED,

    pub fn from_byte(byte: u8) OPCode {
        switch (byte) {
            0 => return OPCode.QUERY,
            1 => return OPCode.IQUERY,
            2 => return OPCode.STATUS,
            3 => return OPCode.UNASSIGNED,
            4 => return OPCode.NOTIFY,
            5 => return OPCode.UPDATE,
            6 => return OPCode.DSO,
            else => return OPCode.UNASSIGNED,
        }
    }
};
