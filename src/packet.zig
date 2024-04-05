const std = @import("std");
const os = std.os;
const DnsQuestion = @import("question.zig").DnsQuestion;
const QType = @import("question.zig").QType;
const QClass = @import("question.zig").QClass;
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const Record = @import("record.zig").Record;
const Header = @import("header.zig").Header;
const Buffer = @import("buffer.zig").Buffer;
const string = @import("string.zig");
const DataInner = @import("record.zig").DataInner;

pub const DnsPacket = struct {
    header: Header,
    questions: ArrayList(DnsQuestion),
    answers: ArrayList(Record),
    name_servers: ArrayList(Record),
    additional_records: ArrayList(Record),

    buffer: Buffer,

    pub fn new() DnsPacket {
        return DnsPacket{
            .header = undefined,
            .questions = ArrayList(DnsQuestion).init(allocator.allocator()),
            .answers = ArrayList(Record).init(allocator.allocator()),
            .name_servers = ArrayList(Record).init(allocator.allocator()),
            .additional_records = ArrayList(Record).init(allocator.allocator()),
            .buffer = Buffer.new_empty(),
        };
    }

    pub fn get_buffer(self: *DnsPacket) []u8 {
        return self.buffer.buffer[0..];
    }

    pub fn parse(self: *DnsPacket) !void {
        self.header = try Header.from_bytes(&self.buffer);
        self.questions = try DnsQuestion.all_from_bytes(self.header.qd_count, &self.buffer);
        self.answers = try Record.from_bytes(self.header.an_count, &self.buffer);
        self.name_servers = try Record.from_bytes(self.header.ns_count, &self.buffer);
        self.additional_records = try Record.from_bytes(self.header.ar_count, &self.buffer);
        self.buffer.index = 0;
    }

    pub fn to_buffer(self: *DnsPacket) Buffer {
        var new_buffer = Buffer.new_empty();

        // UNKNOWN types er uithalen
        self.filter();

        self.header.write_buffer(&new_buffer);

        for (self.questions.items) |q| {
            q.write_buffer(&new_buffer);
        }
        for (self.answers.items) |a| {
            a.write_buffer(&new_buffer);
        }
        for (self.name_servers.items) |q| {
            q.write_buffer(&new_buffer);
        }
        for (self.additional_records.items) |q| {
            q.write_buffer(&new_buffer);
        }
        return new_buffer;
    }

    pub fn resolve(self: *DnsPacket) !void {
        var ns_ip = [_]u8{ 198, 41, 0, 4 }; // root dns server

        while (true) {
            try self.send(ns_ip, self.questions.items[0].QType);
            // self.print();

            if (self.answers.items.len != 0) {
                std.debug.print("DONE\n", .{});
                self.print();
                return;
            }

            const opt_nameserver_ip = self.nameserver_resolved(&self.questions.items[0].cname);
            if (opt_nameserver_ip) |ip| {
                self.into_response();
                ns_ip = ip;
                continue;
            }

            var recursive_q = DnsPacket.new();
            const domain_name = self.nameserver_unresolved(&self.questions.items[0].cname) orelse continue;
            recursive_q.buffer.buffer = self.buffer.buffer;

            try recursive_q.questions.append(DnsQuestion{
                .cname = domain_name,
                .QType = QType.A,
                .QClass = QClass.InternetAdress
            });
            recursive_q.header.header_inner.qr = 1;
            recursive_q.header.qd_count = 1;
            std.debug.print("RECURSIVE\n", .{});
            try recursive_q.resolve();
            ns_ip = recursive_q.get_a_record() orelse unreachable;
            continue;
        }
    }

    pub fn into_response(self: *DnsPacket) void {
        self.clear_records();
        self.header.set_recursion_desired(false);
        self.header.header_inner.RCODE = 0;
        self.header.header_inner.TC = 0;
        self.header.header_inner.qr = 0;
    }
    pub fn clear_records(self: *DnsPacket) void {
        self.header.ns_count = 0;
        self.header.ar_count = 0;
        self.name_servers.clearRetainingCapacity();
        self.additional_records.clearRetainingCapacity();
    }

    pub fn nameserver_resolved(self: *DnsPacket, domain_name: *string.String) ?[4]u8 {
        for (self.name_servers.items) |*ns| {
            if (!string.ends_with(&ns.name, domain_name)) {
                continue;
            }
            for (self.additional_records.items) |*ar| {
                switch (ns.r_data.data) {
                    DataInner.NS => |*n| {
                        std.debug.print("n {s} ns {s}\n", .{n.items, ar.name.items});
                        if (!string.eq(n, &ar.name)) {
                            continue;
                        }
                    },
                    else => continue,
                }

                switch (ar.r_data.data) {
                    DataInner.A => |ip| return ip,
                    else => continue,
                }
            }
        }
        return null;
    }

    pub fn nameserver_unresolved(self: * DnsPacket, domain_name: * string.String) ?string.String {
        for (self.name_servers.items) |*ns| {
            if (!string.ends_with(&ns.name, domain_name)) {
                continue;
            }
            switch (ns.r_data.data) {
                DataInner.NS => |n| {return n; },
                else => continue,
        }
        }
        return null;
    }

    pub fn get_a_record(self: * DnsPacket) ?[4]u8 {
        for (self.answers.items) |a| {
            switch (a.r_data.data){
                DataInner.A => |ip| return ip,
                else => continue
            }
        }
        return null;
    }

    pub fn filter(self: *DnsPacket) void {
        self.header.qd_count = DnsPacket.count_known_question(&self.questions);
        self.header.an_count = DnsPacket.count_known_records(&self.answers);
        self.header.ns_count = DnsPacket.count_known_records(&self.name_servers);
        self.header.ar_count = DnsPacket.count_known_records(&self.additional_records);
    }

    fn count_known_question(records: *ArrayList(DnsQuestion)) u16 {
        var question_count: u16 = 0;
        for (records.items) |r| {
            if (r.QType == QType.Unsupported) {
                continue;
            } else if (r.QClass == QClass.NotSupported) {
                continue;
            }
            question_count = question_count + 1;
        }
        return question_count;
    }

    fn count_known_records(records: *ArrayList(Record)) u16 {
        var record_count: u16 = 0;
        for (records.items) |r| {
            if (r.type == QType.Unsupported) {
                continue;
            } else if (r.class == QClass.NotSupported) {
                continue;
            }
            record_count = record_count + 1;
        }
        return record_count;
    }

    pub fn print(self: *const DnsPacket) void {
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
        }
        std.debug.print("\n", .{});

        std.debug.print("NAME SERVERS\n", .{});
        for (self.name_servers.items) |a| {
            a.print();
        }
        std.debug.print("\n", .{});

        std.debug.print("ADDITIONAL RECORDS\n", .{});
        for (self.additional_records.items) |a| {
            a.print();
        }
        std.debug.print("\n", .{});
    }

    pub fn deinit(self: DnsPacket) void {
        self.questions.deinit();
        self.answers.deinit();
    }

    pub fn send(self: *DnsPacket, ip: [4]u8, class: QType) !void {

        const client_socket = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        defer os.closeSocket(client_socket);

        const client_addr = std.net.Address.initIp4(ip, 53);
        try os.connect(client_socket, &client_addr.any, client_addr.getOsSockLen());

        self.questions.items[0].QType = class;


        std.debug.print("---- sending {}\n", .{client_addr});
        var b = self.to_buffer();
        self.print();

        std.debug.print("----/ sending\n", .{});
        const send_bytes = try os.send(client_socket,b.slice_from_start(), 0);
        _ = send_bytes;


        std.debug.print("---- response\n", .{});
        const upstream_len = try os.recv(client_socket, self.get_buffer(), 0);
        _ = upstream_len;
        self.buffer.index = 0;
        try self.parse();
        self.print();
        std.debug.print("----/ response\n", .{});
    }
};
