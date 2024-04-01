const std = @import("std");
const DnsQuestion = @import("question.zig").DnsQuestion;
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const Record = @import("record.zig").Record;
const Header = @import("header.zig").Header;
const Buffer = @import("buffer.zig").Buffer;

pub const DnsPacket = struct {
    header:Header,
    questions: ArrayList(DnsQuestion),
    answers: ArrayList(Record),

    pub fn from_bytes(bytes: *Buffer) !DnsPacket {
        std.debug.print("-- parse header\n", .{});
        const header = try Header.from_bytes(bytes);
        std.debug.print("-- parse header\n", .{});


        std.debug.print("-- parse questions\n", .{});
        const questions = try DnsQuestion.all_from_bytes(header.qd_count, bytes);
        std.debug.print("-- parse questions\n", .{});


        std.debug.print("-- parse record\n", .{});
        const result2 = try Record.from_bytes(header.an_count, bytes);
        std.debug.print("-- parse record\n", .{});


        return DnsPacket{
            .header = header,
            .questions = questions,
            .answers = result2
        };
    }

    pub fn write(bytes: []u8) !void {
        _ = bytes;

    }
};
