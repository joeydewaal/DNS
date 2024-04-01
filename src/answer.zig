const std = @import("std");
var allocator = std.heap.GeneralPurposeAllocator(.{}){};
const ArrayList = std.ArrayList;
const Label = []u8;

pub const DnsAnswer = struct {
    name: ArrayList(Label),
    type: u16,
    class_code: u16,
    ttl: u32,
    rd_length: u16,
};
