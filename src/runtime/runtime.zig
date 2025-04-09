const std = @import("std");

const MemorySystem = @import("memory.zig");
const RegisterSystem = @import("register.zig");
const Register = RegisterSystem.Register;
const Instruction = @import("instruction.zig").Instruction;
const Runtime = @This();

registers: RegisterSystem,
memory: MemorySystem,
programStart: u32,
allocator: std.mem.Allocator,
stdin: std.io.AnyReader,
stdout: std.io.AnyWriter,

pub fn init(memory_size: u64, program_start: u32, reader: std.io.AnyReader, allocator: std.mem.Allocator, stdin: std.io.AnyReader, stdout: std.io.AnyWriter) !Runtime {
    const mem = try allocator.alloc(u32, memory_size);
    var idx = program_start;
    while (reader.readInt(u32, .big)) |word| {
        mem[idx] = word;
        idx += 1;
    } else |_| {}
    var rt = Runtime{
        .memory = .{ .data = mem },
        .registers = .{ .registers = undefined },
        .programStart = program_start,
        .allocator = allocator,
        .stdin = stdin,
        .stdout = stdout,
    };
    @memset(&rt.registers.registers, 0);
    rt.registers.register_set(.IP, program_start);
    rt.registers.register_set(.SP, program_start);
    return rt;
}

pub fn deinit(self: *Runtime) void {
    self.allocator.free(self.memory.data);
    self.* = undefined;
}

fn nextInstruction(self: *Runtime) !Instruction {
    const idx = self.registers.register_get(.IP);
    self.registers.register_set(.IP, idx + 1);
    return Instruction.fromWord(self.memory.readWord(idx + 1));
}

fn getInstruction(self: *Runtime, idx: u32) !Instruction {
    self.registers.register_set(.IP, idx);
    return Instruction.fromWord(self.memory.readWord(idx));
}

fn interruptHandler(self: *Runtime) !void {
    const kind = self.registers.register_get(.RA);
    switch (kind) {
        0 => console: {
            const method = self.registers.register_get(.RB);
            switch (method) {
                0 => input_text: {
                    const address = self.registers.register_get(.RC);
                    const ptr = @as([*]u8, @ptrFromInt(@as(usize, @intFromPtr(self.memory.data[address..].ptr))));
                    const slice = try self.stdin.readUntilDelimiter(ptr[0..((self.memory.data.len - address) * 4)], '\n');
                    self.registers.register_set(.RD, @truncate(slice.len));
                    break :input_text;
                },
                1 => output_text: {
                    const address = self.registers.register_get(.RC);
                    const len = self.registers.register_get(.RD);
                    const ptr = @as([*]u8, @ptrFromInt(@as(usize, @intFromPtr(self.memory.data[address..].ptr))));
                    try self.stdout.writeAll(ptr[0..len]);
                    break :output_text;
                },
                else => @panic("Invalid interrupt."),
            }
            break :console;
        },
        else => @panic("Invalid interrupt."),
    }
}

pub fn start(self: *Runtime) !void {
    eval: switch (try self.nextInstruction()) {
        // zero registers
        .Hlt => {
            break :eval;
        },
        .Int => {
            try self.interruptHandler();
            continue :eval try self.nextInstruction();
        },
        // one register
        .Psh => |reg| {
            const value = self.registers.register_get(reg);
            const sp = self.registers.register_get(.SP);
            const new_sp = sp - 1;
            self.memory.writeWord(new_sp, value);
            self.registers.register_set(.SP, new_sp);
            continue :eval try self.nextInstruction();
        },
        .Pop => |reg| {
            const sp = self.registers.register_get(.SP);
            const new_sp = sp + 1;
            const value = self.memory.readWord(sp);
            self.registers.register_set(reg, value);
            self.registers.register_set(.SP, new_sp);
            continue :eval try self.nextInstruction();
        },
        .Jmp => |reg| {
            continue :eval try self.getInstruction(self.registers.register_get(reg));
        },
        // register and immediate
        .Mil => |pair| {
            const reg = @as(Register, pair.reg);
            const imm = @as(u16, pair.imm);
            self.registers.register_set_low_half(reg, imm);
            continue :eval try self.nextInstruction();
        },
        .Miu => |pair| {
            const reg = @as(Register, pair.reg);
            const imm = @as(u16, pair.imm);
            self.registers.register_set_high_half(reg, imm);
            continue :eval try self.nextInstruction();
        },
        // two registers
        .Mov => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const value = self.registers.register_get(b);
            self.registers.register_set(a, value);
            continue :eval try self.nextInstruction();
        },
        .Neg => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const value = self.registers.register_get(b);
            self.registers.register_set(a, @as(u32, @bitCast(-@as(i32, @bitCast(value)))));
            continue :eval try self.nextInstruction();
        },
        .Not => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const value = self.registers.register_get(b);
            self.registers.register_set(a, ~value);
            continue :eval try self.nextInstruction();
        },
        .Negf => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const value = self.registers.register_get(b);
            self.registers.register_set(a, @as(u32, @bitCast(-@as(f32, @floatFromInt(value)))));
            continue :eval try self.nextInstruction();
        },
        .Itof => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const value = self.registers.register_get(b);
            self.registers.register_set(a, @as(u32, @bitCast(@as(f32, @floatFromInt(value)))));
            continue :eval try self.nextInstruction();
        },
        .Ftoi => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const value = self.registers.register_get(b);
            self.registers.register_set(a, @as(u32, @intFromFloat(@as(f32, @bitCast(value)))));
            continue :eval try self.nextInstruction();
        },
        .Rwd => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const addr = self.registers.register_get(b);
            const word = self.memory.readWord(addr);
            self.registers.register_set(a, word);
            continue :eval try self.nextInstruction();
        },
        .Wwd => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const addr = self.registers.register_get(a);
            const word = self.registers.register_get(b);
            self.memory.writeWord(addr, word);
            continue :eval try self.nextInstruction();
        },
        .Jif => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            if (self.registers.register_get(a) != 0) {
                continue :eval try self.getInstruction(self.registers.register_get(b));
            }
            continue :eval try self.nextInstruction();
        },
        // three registers
        .Jeq => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            if (self.registers.register_get(a) == self.registers.register_get(b)) {
                continue :eval try self.getInstruction(self.registers.register_get(c));
            }
            continue :eval try self.nextInstruction();
        },
        .Add => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const add_result = @addWithOverflow(v1, v2);
            self.registers.register_set(a, add_result[0]);
            self.registers.set_flag(.overflow, add_result[1]);
            continue :eval try self.nextInstruction();
        },
        .Sub => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const sub_result = @subWithOverflow(v1, v2);
            self.registers.register_set(a, sub_result[0]);
            self.registers.set_flag(.overflow, sub_result[1]);
            continue :eval try self.nextInstruction();
        },
        .Addf => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = @as(f32, @bitCast(self.registers.register_get(b)));
            const v2 = @as(f32, @bitCast(self.registers.register_get(c)));
            const result = @as(u32, @bitCast(v1 + v2));
            self.registers.register_set(a, result);
            continue :eval try self.nextInstruction();
        },
        .Subf => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = @as(f32, @bitCast(self.registers.register_get(b)));
            const v2 = @as(f32, @bitCast(self.registers.register_get(c)));
            const result = @as(u32, @bitCast(v1 - v2));
            self.registers.register_set(a, result);
            continue :eval try self.nextInstruction();
        },
        .Xor => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const result: u32 = v1 ^ v2;
            self.registers.register_set(a, result);
            continue :eval try self.nextInstruction();
        },
        .Or => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const result: u32 = v1 | v2;
            self.registers.register_set(a, result);
            continue :eval try self.nextInstruction();
        },
        .And => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const result: u32 = v1 & v2;
            self.registers.register_set(a, result);
            continue :eval try self.nextInstruction();
        },
        .Shl => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const result = std.math.shl(u32, v1, v2);
            self.registers.register_set(a, result);
            continue :eval try self.nextInstruction();
        },
        .Shr => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const result = std.math.shr(u32, v1, v2);
            self.registers.register_set(a, result);

            continue :eval try self.nextInstruction();
        },
        .Cmp => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = self.registers.register_get(b);
            const v2 = self.registers.register_get(c);
            const order = std.math.order(v1, v2);
            self.registers.register_set(a, switch (order) {
                .gt => 1,
                .lt => 2,
                .eq => 4,
            });
            continue :eval try self.nextInstruction();
        },
        .Mulf => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = @as(f32, @floatFromInt(self.registers.register_get(b)));
            const v2 = @as(f32, @floatFromInt(self.registers.register_get(c)));
            const result = @as(f32, v1 * v2);
            self.registers.register_set(a, @as(u32, @bitCast(result)));
            continue :eval try self.nextInstruction();
        },
        .Divf => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const v1 = @as(f32, @floatFromInt(self.registers.register_get(b)));
            const v2 = @as(f32, @floatFromInt(self.registers.register_get(c)));
            const result = @as(f32, v1 / v2);
            self.registers.register_set(a, @as(u32, @bitCast(result)));
            continue :eval try self.nextInstruction();
        },
        // four registers
        .Mul => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const d = @as(Register, regs.d);
            const v1 = self.registers.register_get(c);
            const v2 = self.registers.register_get(d);
            const result = @as(u64, std.math.mulWide(u32, v1, v2));
            const halves = @as([2]u32, @bitCast(result));
            self.registers.register_set(a, halves[0]);
            self.registers.register_set(b, halves[1]);
            continue :eval try self.nextInstruction();
        },
        .Div => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const d = @as(Register, regs.d);
            const v1 = self.registers.register_get(c);
            const v2 = self.registers.register_get(d);
            const result = std.math.divFloor(u32, v1, v2) catch @panic("divide by zero");
            self.registers.register_set(a, result);
            self.registers.register_set(b, @mod(v1, v2));
            continue :eval try self.nextInstruction();
        },
        .Muli => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.a);
            const c = @as(Register, regs.a);
            const d = @as(Register, regs.a);
            const v1 = @as(i32, @bitCast(self.registers.register_get(a)));
            const v2 = @as(i32, @bitCast(self.registers.register_get(b)));
            const result = @as(i64, std.math.mulWide(i32, v1, v2));
            const halves = @as([2]u32, @bitCast(result));
            self.registers.register_set(c, halves[0]);
            self.registers.register_set(d, halves[1]);
            continue :eval try self.nextInstruction();
        },
        .Divi => |regs| {
            const a = @as(Register, regs.a);
            const b = @as(Register, regs.b);
            const c = @as(Register, regs.c);
            const d = @as(Register, regs.d);
            const v1 = @as(i32, @bitCast(self.registers.register_get(c)));
            const v2 = @as(i32, @bitCast(self.registers.register_get(d)));
            const result = std.math.divFloor(i32, v1, v2) catch @panic("divide by zero");

            self.registers.register_set(a, @as(u32, @bitCast(result)));
            self.registers.register_set(b, @as(u32, @bitCast(@mod(v1, v2))));
            continue :eval try self.nextInstruction();
        },
    }
}
