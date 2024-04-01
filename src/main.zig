const std = @import("std");
const os = @import("std").os;
const DnsPacket = @import("packet.zig").DnsPacket;

pub fn main() !void {
    const addr = try std.net.Address.parseIp("127.0.0.1", 53);
    const sock = try std.os.socket(std.os.AF.INET, std.os.SOCK.DGRAM, std.os.IPPROTO.UDP);
    defer std.os.close(sock);
    try std.os.bind(sock, &addr.any, addr.getOsSockLen());

    var cliaddr: std.os.linux.sockaddr = undefined;
    var cliaddrlen: std.os.socklen_t = @sizeOf(os.linux.sockaddr);
    while (true) {
        var buf: [1024]u8 = undefined;
        const len = try os.recvfrom(sock, buf[0..], 0, &cliaddr, &cliaddrlen);
        _ = len;
        const packet = DnsPacket.from_bytes(&buf);

        const send_bytes = try os.sendto(sock, &buf, 0, &cliaddr, cliaddrlen);
        _ = send_bytes;
        std.debug.print("{any}\n", .{packet});
        break;
    }
}
