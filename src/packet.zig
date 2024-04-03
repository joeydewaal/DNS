const std = @import("std");
const DnsQuestion = @import("question.zig").DnsQuestion;
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const Record = @import("record.zig").Record;
const Header = @import("header.zig").Header;
const Buffer = @import("buffer.zig").Buffer;

pub const DnsPacket = struct {
    header: Header,
    questions: ArrayList(DnsQuestion),
    answers: ArrayList(Record),
    name_servers: ArrayList(Record),
    additional_records: ArrayList(Record),

    pub fn from_bytes(bytes: *Buffer) !DnsPacket {
        const header = try Header.from_bytes(bytes);
        header.print();

        const questions = try DnsQuestion.all_from_bytes(header.qd_count, bytes);
        const answers = try Record.from_bytes(header.an_count, bytes);
        const name_servers = try Record.from_bytes(header.ns_count, bytes);
        const additional_records = try Record.from_bytes(header.ns_count, bytes);

        return DnsPacket{
            .header = header,
            .questions = questions,
            .answers = answers,
            .name_servers = name_servers,
            .additional_records = additional_records
        };
    }

    pub fn to_buffer(self: *const DnsPacket) Buffer {
        var buffer = Buffer.new_empty();
        self.header.write_buffer(&buffer);
        for (self.questions.items) |q| {
            q.write_buffer(&buffer);
        }
        for (self.answers.items) |a| {
            a.write_buffer(&buffer);
        }
        for (self.name_servers.items) |q| {
            q.write_buffer(&buffer);
        }
        for (self.additional_records.items) |q| {
            q.write_buffer(&buffer);
        }
        return buffer;
    }

    pub fn print(self: *const DnsPacket) void {
        std.debug.print("-------\n", .{});
        std.debug.print("HEADER\n", .{});
        self.header.print();
        std.debug.print("\n", .{});

        std.debug.print("QUESTIONS\n", .{});
        for (self.questions.items) |q| {
            q.print();
        }
        std.debug.print("\n", .{});

        std.debug.print("ANSWERS\n", .{});
        for (self.answers.items) |a| {
            a.print();
            std.debug.print("--\n", .{});
        }
        std.debug.print("\n", .{});

        std.debug.print("NAME SERVERS\n", .{});
        for (self.name_servers.items) |a| {
            a.print();
            std.debug.print("--\n", .{});
        }
        std.debug.print("\n", .{});

        std.debug.print("ADDITIONAL RECORDS\n", .{});
        for (self.additional_records.items) |a| {
            a.print();
            std.debug.print("--\n", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn deinit(self: DnsPacket) void {
        self.questions.deinit();
        self.answers.deinit();
    }
};
