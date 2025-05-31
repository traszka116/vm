const std = @import("std");
const Runtime = @import("runtime/runtime.zig");
pub fn main() !void {
    const path: []const u8 = "test.bin";
    const stdin = std.io.getStdIn().reader().any();
    const stdout = std.io.getStdOut().writer().any();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    const cwd = std.fs.cwd();
    const file = try cwd.openFile(path, .{});
    const source = file.reader().any();
    var runtime = try Runtime.init(source, stdout, stdin, alloc);
    defer runtime.deinit();
    try runtime.run();
}
