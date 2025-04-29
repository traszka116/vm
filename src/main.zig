const std = @import("std");
const Runtime = @import("runtime/runtime.zig");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const stdout = std.io.getStdOut().writer().any();
    const stdin = std.io.getStdIn().reader().any();

    var file = try std.fs.cwd().openFile("code.bin", .{});
    defer file.close();
    const program_stream = file.reader().any();

    // while (true) {
    //     const n = try program_stream.readInt(u32, .big);
    //     const ptr = std.mem.asBytes(&n);
    //     try stdout.print("{X}\n", .{ptr});
    // }

    // const program = try program_stream.readAllAlloc(alloc, 4096);
    // defer alloc.free(program);
    // try stdout.print("{X}\n", .{program});
    var dump = try std.fs.cwd().createFile("dump.hex", .{});
    defer dump.close();
    var runtime = try Runtime.init(program_stream, alloc, stdin, stdout);
    defer runtime.deinit();
    try dump.writeAll(@ptrCast(runtime.memory.data));
    try runtime.start();
}
