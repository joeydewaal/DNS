const std = @import("std");
const os = @import("std").os;
const DnsPacket = @import("packet.zig").DnsPacket;
const Buffer = @import("buffer.zig").Buffer;

const upstream = "1.1.1.1";
// const upstream = "192.168.0.29";

pub fn main() !void {
    const addr = try std.net.Address.parseIp("127.0.0.1", 53);
    const sock = try std.os.socket(std.os.AF.INET, std.os.SOCK.DGRAM, std.os.IPPROTO.UDP);
    defer std.os.close(sock);
    try std.os.bind(sock, &addr.any, addr.getOsSockLen());

    var cliaddr: std.os.linux.sockaddr = undefined;
    var cliaddrlen: std.os.socklen_t = @sizeOf(os.linux.sockaddr);
    while (true) {

        // client uitlezen
        var buf: [1024]u8 = undefined;
        const len = try os.recvfrom(sock, buf[0..], 0, &cliaddr, &cliaddrlen);


        const upstream_socket = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        defer os.closeSocket(upstream_socket);

        // verbinden met upstream host
        const upstream_addr = try std.net.Address.resolveIp(upstream, 53);
        try os.connect(upstream_socket, &upstream_addr.any, addr.getOsSockLen());

        // client req doorsturen naar upstream
        const send_bytes = try os.send(upstream_socket, buf[0..len], 0);
        _ = send_bytes;

        // std.debug.print("sent up:{d}\n", .{send_bytes});

        var upstream_buf: [1024]u8 = undefined;
        const upstream_len = try os.recv(upstream_socket, upstream_buf[0..], 0);
        // std.debug.print("recv up:{d}\n", .{upstream_len});



        const client_sent = try os.sendto(sock, upstream_buf[0..upstream_len], 0, &cliaddr, cliaddrlen);
        _ = client_sent;

        var buffer = Buffer.from_bytes(upstream_buf[0..upstream_len]);
        // std.debug.print("client up: {d}\n", .{client_sent});
        const packet = try DnsPacket.from_bytes(&buffer);
        _ = packet;

        // std.debug.print("{any}\n", .{packet});

        // write_to_disk(upstream_buf[0..upstream_len]) catch @panic("whoops");
        break;
    }
}

fn write_to_disk(buf: []u8) !void {
    const file = try std.fs.cwd().createFile(
        "example_resp.txt",
        .{ .read = true },
    );
    defer file.close();
    const bytes_read = try file.writeAll(buf);
    _ = bytes_read;
}
