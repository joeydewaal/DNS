const std = @import("std");
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const Label = []u8;

const ArrayList = std.ArrayList;

pub const DnsQuestion = struct {
    labels: ArrayList(Label),
    QType: QType,
    QClass: QClass,

    pub fn from_bytes(bytes: []u8) !struct { packet: DnsQuestion, end: u16 } {
        var start: u16 = 0;
        var labels = ArrayList(Label).init(allocator.allocator());

        while (true) {
            const len = bytes[start];

            if (len == 0) {
                start = start + 1;
                break;
            }
            const end = start + len + 1;
            // std.debug.print("label-len: {d}\n", .{len});
            // std.debug.print("label: {s}\n", .{bytes[start..end]});

            try labels.append(bytes[start..end]);
            start = start + len + 1;
        }

        const q_type = std.mem.readIntSliceBig(u16, bytes[start .. start + 2]);
        start = start + 2;
        // const q_class = std.mem.readIntSliceBig(u16, bytes[start..start + 2]);

        std.debug.print("{s}\n", .{labels.items});

        return .{ .packet = DnsQuestion{
            .labels = labels,
            .QType = QType.from_bytes(q_type),
            .QClass = QClass.InternetAdress,
        }, .end = start };
    }
};

const QType = enum {
    Reserved,
    A,
    NS,
    MD,
    MF,
    CNAME,
    SOA,
    Unimplemented,

    fn from_bytes(bytes: u16) QType {
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

const QClass = enum { InternetAdress };
