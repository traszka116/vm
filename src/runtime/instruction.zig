const std = @import("std");
const Register = @import("register.zig").Register;

const Ctl0Arg = enum { Hlt, Int, Nop };
const Op0 = union(enum) { ctl: Ctl0Arg };
const Args0 = struct {};

const Ctl1Arg = enum { Jmp, Psh, Pop };
const Op1 = union(enum) { ctl: Ctl1Arg };
const Args1 = struct { arg: Register };

const Alu2Reg = enum { Mov, Neg, Not, Negf, Itof, Ftoi };
const Ctl2Arg = enum { Rwd, Wwd, Jif };
const Op2 = union(enum) { alu: Alu2Reg, ctl: Ctl2Arg };
const Args2 = struct { arg1: Register, arg2: Register };

const Alu3Reg = enum { Add, Sub, Addf, Subf, Xor, Or, And, Shl, Shr, Cmp, Cmpi, Cmpf, Mulf, Divf, Mul, Div, Muli, Divi };
const Ctl3Arg = enum { Jeq };
const Op3 = union(enum) { alu: Alu3Reg, ctl: Ctl3Arg };
const Args3 = struct { arg1: Register, arg2: Register, arg3: Register };

const AluRegImm = enum { Miu, Mil };
const OpImm = union(enum) { alu: AluRegImm };
const ArgsImm = struct { reg: Register, imm: u16 };

const Instr0 = struct { op: Op0, arg: Args0 };
const Instr1 = struct { op: Op1, arg: Args1 };
const Instr2 = struct { op: Op2, arg: Args2 };
const Instr3 = struct { op: Op3, arg: Args3 };
const InstrImm = struct { op: OpImm, arg: ArgsImm };

pub const Instruction = union(enum) { i0: Instr0, i1: Instr1, i2: Instr2, i3: Instr3, im: InstrImm };

pub fn decode_instruction(bytes: [4]u8) ?Instruction {
    const opcode = bytes[0];
    switch (opcode) {
        0x00...0x02 => |n| return switch (n) {
            0x00 => .{ .i0 = .{ .op = .{ .ctl = .Hlt }, .arg = .{} } },
            0x01 => .{ .i0 = .{ .op = .{ .ctl = .Int }, .arg = .{} } },
            0x02 => .{ .i0 = .{ .op = .{ .ctl = .Nop }, .arg = .{} } },
            else => unreachable,
        },
        0x03...0x05 => |n| {
            const regi = decode_register(bytes[1]) orelse return null;
            return switch (n) {
                0x03 => .{ .i1 = .{ .op = .{ .ctl = .Jmp }, .arg = .{ .arg = regi } } },
                0x04 => .{ .i1 = .{ .op = .{ .ctl = .Psh }, .arg = .{ .arg = regi } } },
                0x05 => .{ .i1 = .{ .op = .{ .ctl = .Pop }, .arg = .{ .arg = regi } } },
                else => unreachable,
            };
        },
        0x06...0x0E => |n| {
            const reg1 = decode_register(bytes[1]) orelse return null;
            const reg2 = decode_register(bytes[2]) orelse return null;
            return switch (n) {
                0x06 => .{ .i2 = .{ .op = .{ .alu = .Mov }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x07 => .{ .i2 = .{ .op = .{ .alu = .Neg }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x08 => .{ .i2 = .{ .op = .{ .alu = .Not }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x09 => .{ .i2 = .{ .op = .{ .alu = .Negf }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x0A => .{ .i2 = .{ .op = .{ .alu = .Itof }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x0B => .{ .i2 = .{ .op = .{ .alu = .Ftoi }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x0C => .{ .i2 = .{ .op = .{ .ctl = .Rwd }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x0D => .{ .i2 = .{ .op = .{ .ctl = .Wwd }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                0x0E => .{ .i2 = .{ .op = .{ .ctl = .Jif }, .arg = .{ .arg1 = reg1, .arg2 = reg2 } } },
                else => unreachable,
            };
        },
        0x0F...0x10 => |n| {
            const reg = decode_register(bytes[1]);
            const imm = decode_immediate(.{ bytes[2], bytes[3] });
            return switch (n) {
                0x0F => .{ .im = .{ .op = .Miu, .arg = .{ .reg = reg, .imm = imm } } },
                0x10 => .{ .im = .{ .op = .Mil, .arg = .{ .reg = reg, .imm = imm } } },
                else => unreachable,
            };
        },
        0x11...0x23 => |n| {
            const r1 = decode_register(bytes[0]) orelse return null;
            const r2 = decode_register(bytes[0]) orelse return null;
            const r3 = decode_register(bytes[0]) orelse return null;
            return switch (n) {
                0x11 => .{ .i3 = .{ .op = .{ .ctl = .Jeq }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x12 => .{ .i3 = .{ .op = .{ .alu = .Add }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x13 => .{ .i3 = .{ .op = .{ .alu = .Sub }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x14 => .{ .i3 = .{ .op = .{ .alu = .Addf }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x15 => .{ .i3 = .{ .op = .{ .alu = .Subf }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x16 => .{ .i3 = .{ .op = .{ .alu = .Xor }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x17 => .{ .i3 = .{ .op = .{ .alu = .Or }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x18 => .{ .i3 = .{ .op = .{ .alu = .And }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x19 => .{ .i3 = .{ .op = .{ .alu = .Shl }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x1A => .{ .i3 = .{ .op = .{ .alu = .Shr }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x1B => .{ .i3 = .{ .op = .{ .alu = .Cmp }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x1C => .{ .i3 = .{ .op = .{ .alu = .Cmpi }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x1D => .{ .i3 = .{ .op = .{ .alu = .Cmpf }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x1E => .{ .i3 = .{ .op = .{ .alu = .Mulf }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x1F => .{ .i3 = .{ .op = .{ .alu = .Divf }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x20 => .{ .i3 = .{ .op = .{ .alu = .Mul }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x21 => .{ .i3 = .{ .op = .{ .alu = .Div }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x22 => .{ .i3 = .{ .op = .{ .alu = .Muli }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                0x23 => .{ .i3 = .{ .op = .{ .alu = .Divi }, .arg = .{ .arg1 = r1, .arg2 = r2, .arg3 = r3 } } },
                else => unreachable,
            };
        },
        else => return null,
    }
}

fn decode_register(byte: u8) ?Register {
    return switch (byte) {
        0x00 => .RA,
        0x01 => .RB,
        0x02 => .RC,
        0x03 => .RD,
        0x04 => .R0,
        0x05 => .R1,
        0x06 => .R2,
        0x07 => .R3,
        0x08 => .R4,
        0x09 => .R5,
        0x0A => .R6,
        0x0B => .R7,
        0x0C => .SP,
        0x0D => .RF,
        0x0E => .IP,
        0x0F => .RT,
        else => null,
    };
}
fn decode_immediate(bytes: [2]u8) u16 {
    return @as(u16, bytes[0]) << 16 | @as(u16, bytes[1]);
}
