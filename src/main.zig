const std = @import("std");
const os = @import("std").os;
const DnsPacket = @import("packet.zig").DnsPacket;
const Buffer = @import("buffer.zig").Buffer;
const MAX_BUFF = @import("buffer.zig").MAX_BUFF;

pub fn main() !void {
    const addr = try std.net.Address.parseIp("127.0.0.1", 53);
    const sock = try std.os.socket(std.os.AF.INET, std.os.SOCK.DGRAM, std.os.IPPROTO.UDP);
    defer std.os.close(sock);
    try std.os.bind(sock, &addr.any, addr.getOsSockLen());

    while (true) {
        var dns_packet = DnsPacket.new();

        var cliaddr: std.os.linux.sockaddr = undefined;
        var cliaddrlen: std.os.socklen_t = @sizeOf(os.linux.sockaddr);

        // buffer vullen met request data
        const len = try os.recvfrom(sock, dns_packet.get_buffer(), 0, &cliaddr, &cliaddrlen);
        _ = len;

        // dns pakket maken van buffer
        try dns_packet.parse();
        try dns_packet.resolve();

        dns_packet.buffer.index = 0;
        const client_sent = try os.sendto(sock, dns_packet.to_buffer().slice_from_start(), 0, &cliaddr, cliaddrlen);
        _ = client_sent;
    }
}


