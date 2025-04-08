const std = @import("std");
const Runtime = @import("runtime/runtime.zig");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const stdout = std.io.getStdOut().writer().any();
    const stdin = std.io.getStdIn().reader().any();
    const program = [_]u8{
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };

    var instructions = std.io.fixedBufferStream(&program);
    const instruction_stream = instructions.reader();
    var runtime = try Runtime.init(2 * 1024 * 1024, 4 * 1024, instruction_stream.any(), alloc, stdin, stdout);
    defer runtime.deinit();
    try runtime.start();
}
