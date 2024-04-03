const std = @import("std");
const os = @import("std").os;
const DnsPacket = @import("packet.zig").DnsPacket;
const Buffer = @import("buffer.zig").Buffer;
const MAX_BUFF = @import("buffer.zig").MAX_BUFF;

// const upstream = "1.1.1.1";
// const upstream = "192.168.0.29";
const upstream = "198.41.0.4";

pub fn main() !void {
    const addr = try std.net.Address.parseIp("127.0.0.1", 53);
    const sock = try std.os.socket(std.os.AF.INET, std.os.SOCK.DGRAM, std.os.IPPROTO.UDP);
    defer std.os.close(sock);
    try std.os.bind(sock, &addr.any, addr.getOsSockLen());

    var cliaddr: std.os.linux.sockaddr = undefined;
    var cliaddrlen: std.os.socklen_t = @sizeOf(os.linux.sockaddr);
    while (true) {

        // nieuwe buffer maken voor binnenkomende request
        var client_buff = Buffer.new_empty();
        //
        // buffer vullen met request
        const len = try os.recvfrom(sock, client_buff.slice_to_end(), 0, &cliaddr, &cliaddrlen);
        _ = len;

        // dns pakket maken van buffer
        const client_packet = try DnsPacket.from_bytes(&client_buff);
        defer client_packet.deinit();

        // debug: pakket uitprinten
        std.debug.print("---------client\n", .{});
        client_packet.print();
        std.debug.print("---------client\n", .{});

        // upstream connectie maken
        const upstream_socket = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        defer os.closeSocket(upstream_socket);

        // verbinden met upstream host
        const upstream_addr = try std.net.Address.resolveIp(upstream, 53);
        try os.connect(upstream_socket, &upstream_addr.any, addr.getOsSockLen());

        // client req doorsturen naar upstream
        const send_bytes = try os.send(upstream_socket, client_packet.to_buffer().slice_from_start(), 0);
        _ = send_bytes;

        // std.debug.print("sent up:{d}\n", .{send_bytes});

        // upstream antwoord opvangen
        var upstream_buf = Buffer.new_empty();
        const upstream_len = try os.recv(upstream_socket, upstream_buf.slice_to_end(), 0);
        _ = upstream_len;
        const uppstream_packet = try DnsPacket.from_bytes(&upstream_buf);
        std.debug.print("---------upstream\n", .{});
        uppstream_packet.print();
        std.debug.print("---------upstream\n", .{});
        const client_sent = try os.sendto(sock, uppstream_packet.to_buffer().slice_from_start(), 0, &cliaddr, cliaddrlen);
        _ = client_sent;
    }
}
