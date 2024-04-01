const std = @import("std");
const DnsQuestion = @import("question.zig").DnsQuestion;
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const DnsAnswer = @import("answer.zig").DnsAnswer;

pub const DnsPacket = struct {
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

    questions: ?ArrayList(DnsQuestion),
    answers: ?ArrayList(DnsAnswer),

    pub fn from_bytes(bytes: []u8) !DnsPacket {
        const id = std.mem.readIntSliceBig(u16, bytes[0..2]);
        const qr = QR.from_byte(bytes[2] >> 7);
        const op_code = OPCode.from_byte(bytes[2] >> 3);
        const r_code = RCODE.from_byte(bytes[3] & 15);

        const qd_count = std.mem.readIntSliceBig(u16, bytes[4..6]);

        var questions = ArrayList(DnsQuestion).init(allocator.allocator());
        var i: u16 = 0;
        var start: u16 = 12;
        while (i < qd_count) {
            i = i + 1;

            const question = try DnsQuestion.from_bytes(bytes[start..bytes.len]);
            const end = question.end;
            try questions.append(question.packet);
            start = start + end;
        }

        return DnsPacket{
            .id = id,
            .qr = qr,
            .op_code = op_code,
            .AA = bytes[2] & (1 << 2) != 0,
            .TC = bytes[2] & (1 << 1) != 0,
            .RD = bytes[2] & 1 != 0,
            .RA = bytes[3] & (1 << 7) != 0,
            .Z = 0,
            .RCODE = r_code,
            .qd_count = qd_count,
            .an_count = std.mem.readIntSliceBig(u16, bytes[6..8]),
            .ns_count = std.mem.readIntSliceBig(u16, bytes[8..10]),
            .ar_count = std.mem.readIntSliceBig(u16, bytes[10..12]),
            .questions = questions,
            .answers = null,
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
    YXDomain,
    YXRRSet,
    NXRRSet,
    NotAuth,
    NotZone,
    DSOTYPENI,
    BADVERS,
    BADSIG,
    BADKEY,
    BADTIME,
    BADMODE,
    BADNAME,
    BADALG,
    BADTRUNC,
    BADCOOKIE,

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
            6 => RCODE.YXDomain,
            7 => RCODE.YXRRSet,
            8 => RCODE.NXRRSet,
            9 => RCODE.NotAuth,
            10 => RCODE.NotZone,
            11 => RCODE.DSOTYPENI,
            16 => RCODE.BADVERS,
            // 16    => RCODE.BADSIG,
            17 => RCODE.BADKEY,
            18 => RCODE.BADTIME,
            19 => RCODE.BADMODE,
            20 => RCODE.BADNAME,
            21 => RCODE.BADALG,
            22 => RCODE.BADTRUNC,
            23 => RCODE.BADCOOKIE,
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
