const std = @import("std");

const Instructions = @import("instruction.zig");
const Instruction = Instructions.Instruction;
const Cpu = @import("cpu.zig");
const Memory = @import("memory.zig");
const Runtime = @This();

const Config = packed struct {
    magic: [4]u8,
    hcode: u32,
    stack_size: u32,
    program_size: u32,
    static_size: u32,
    heap_size: u32,
    entry_point: u32,
    reserved: [16]u8,
};

cpu: Cpu,
memory: Memory,
stdout: std.io.AnyWriter,
stdin: std.io.AnyReader,
source: std.io.AnyReader,
allocator: std.mem.Allocator,
config: Config,

pub fn init(source: std.io.AnyReader, stdout: std.io.AnyWriter, stdin: std.io.AnyReader, allocator: std.mem.Allocator) !Runtime {
    var self: Runtime = undefined;
    self.config = try read_config(source);
    if (!std.mem.eql(u8, &self.config.magic, "XLSD")) {
        return error.InvalidMagicNumber;
    }

    const memory_size = self.config.stack_size + self.config.program_size + self.config.static_size + self.config.heap_size;
    self.memory.data = try allocator.alloc(u32, (memory_size));
    errdefer allocator.free(self.memory.data);

    const data = self.memory.data;
    _ = try source.readAll(data[self.config.stack_size..]);

    self.cpu.running = true;
    self.cpu.registers.registers = undefined;
    self.stdin = stdin;
    self.stdout = stdout;
    self.allocator = allocator;
    self.source = source;
    const program_start = self.config.entry_point;
    self.cpu.registers.register_set(.IP, program_start);
    return self;
}

pub fn deinit(self: *Runtime) void {
    self.allocator.free(self.window);
    self.allocator.free(self.memory.data);
    self.* = undefined;
}

pub fn run(self: *Runtime) !void {
    while (self.cpu.running) {
        const ip = self.cpu.registers.register_get(.IP);
        const word = [4]u8{ self.source[ip], self.source[ip + 1], self.source[ip + 2], self.source[ip + 3] };
        const instruction = Instructions.decode_instruction(word);
        const effect = self.cpu.run_instruction(instruction, self.memory);
        if (effect == .Interrupt) {
            self.interrupt_handler();
        }
    }
}

fn interrupt_handler(self: *Runtime) !void {
    const mode = self.cpu.registers.register_get(.RA);
    const command = self.cpu.registers.register_get(.RB);
    return (switch (mode) {
        0 => self.console_handler(command),
        else => error.InvalidMode,
    }) catch error.InvalidInterrupt;
}

fn console_handler(self: Runtime, command: u32) !void {
    return switch (command) {
        0 => self.write_str(),
        1 => self.write_char(),
        2 => self.read_char(),
        3 => self.read_str(),
        4 => self.write_int(),
        5 => self.write_uint(),
        6 => self.write_float(),
        7 => self.read_int(),
        8 => self.read_uint(),
        9 => self.read_float(),
        else => error.InvalidCommand,
    };
}

fn write_str(self: Runtime) !void {
    const addr = self.cpu.registers.register_get(.RC);
    const len = self.cpu.registers.register_get(.RD);
    const slice: []const u8 = @as(u8, @ptrCast(self.memory.data.ptr))[addr * 4 .. addr * 4 + len];
    try self.stdout.writeAll(slice);
}
fn read_str(self: Runtime) !void {
    const addr = self.cpu.registers.register_get(.RC);
    const len = self.cpu.registers.register_get(.RD);
    const buff: []u8 = @as(u8, @ptrCast(self.memory.data.ptr))[addr * 4 .. addr * 4 + len];
    const read = try self.stdin.readAll(buff);
    self.cpu.registers.register_set(.RD, @as(u32, @truncate(read)));
}
fn write_char(self: Runtime) !void {
    const val = @as(u8, @truncate(self.cpu.registers.register_get(.RC)));
    try self.stdout.writeByte(val);
}
fn read_char(self: Runtime) !void {
    const val = try self.stdin.readByte();
    self.cpu.registers.register_set(.RC, val);
}
fn write_int(self: Runtime) !void {
    const val = @as(i32, @bitCast(self.cpu.registers.register_get(.RC)));
    try self.stdout.print("{d}", .{val});
}
fn write_uint(self: Runtime) !void {
    const val = self.cpu.registers.register_get(.RC);
    try self.stdout.print("{d}", .{val});
}
fn write_float(self: Runtime) !void {
    const val = @as(f32, @bitCast(self.cpu.registers.register_get(.RC)));
    try self.stdout.print("{f}", .{val});
}
fn read_int(self: Runtime) !void {
    var buf: [64]u8 = undefined;
    const line = try self.stdin.readUntilDelimiterOrEof(&buf, '\n');
    if (line) |l| {
        const val = try std.fmt.parseInt(i32, l, 10);
        self.cpu.registers.register_set(.RC, @as(u32, @bitCast(val)));
    } else {
        return error.ReadError;
    }
}
fn read_uint(self: Runtime) !void {
    var buf: [32]u8 = undefined;
    const line = try self.stdin.readUntilDelimiterOrEof(&buf, '\n');
    if (line) |l| {
        const val = try std.fmt.parseInt(u32, l, 10);
        self.cpu.registers.register_set(.RC, val);
    } else {
        return error.ReadError;
    }
}
fn read_float(self: Runtime) !void {
    var buf: [32]u8 = undefined;
    const line = try self.stdin.readUntilDelimiterOrEof(&buf, '\n');
    if (line) |l| {
        const val = try std.fmt.parseFloat(f32, l);
        self.cpu.registers.register_set(.RC, @as(u32, @bitCast(val)));
    } else {
        return error.ReadError;
    }
}
fn read_config(stream: std.io.AnyReader) !Config {
    var config: Config = undefined;
    for (&config.magic) |*b| {
        b.* = try stream.readByte();
    }

    config.hcode = try stream.readInt(u32, .big);
    config.stack_size = try stream.readInt(u32, .big);
    config.program_size = try stream.readInt(u32, .big);
    config.static_size = try stream.readInt(u32, .big);
    config.heap_size = try stream.readInt(u32, .big);
    config.entry_point = try stream.readInt(u32, .big);

    for (&config.reserved) |*b| {
        b.* = try stream.readByte();
    }
    return config;
}
