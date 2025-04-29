const RegisterSystem = @import("register.zig");
const std = @import("std");
pub const OpCode = enum(u8) {
    /// stops runtime
    Hlt = 0,
    /// performs input/output operations depending on register values
    Int,

    /// push reg1 on stack
    Psh,
    /// pops value from stack to reg1
    Pop,
    /// unconditional jump to instruction on address reg1
    Jmp,

    /// set upper part reg1 to immediate
    Miu,
    /// set lower part reg1 to immediate
    Mil,
    /// sets reg1 to reg2
    Mov,

    /// reg1 = -reg2
    Neg,
    /// reg1 = ~reg2
    Not,
    /// reg1 = -(reg2)
    Negf,

    /// reg1 = into float (reg2)
    Itof,
    /// reg1 = into int (reg2)
    Ftoi,

    /// read word from memory[reg2] to reg1
    Rwd,
    /// write word from reg2 to memory[reg1]
    Wwd,

    /// jump to instruction on address reg2 if reg1 != 0
    Jif,
    /// jump to instruction on address reg3 if reg1 == reg2
    Jeq,

    /// reg1 = reg2 + reg3
    Add,
    /// reg1 = reg2 - reg3
    Sub,

    /// reg1 = (reg2) + (reg3)
    Addf,
    /// reg1 = (reg2) - (reg3)
    Subf,

    /// reg1 = reg2 ^ reg3
    Xor,
    /// reg1 = reg2 | reg3
    Or,
    /// reg1 = reg2 & reg3
    And,
    /// reg1 = reg2 << reg3
    Shl,
    /// reg1 = reg2 >> reg3
    Shr,

    /// compare reg2 and reg3
    /// puts one of following values into reg1
    /// 2^0 (1) if reg2 > reg3
    /// 2^1 (2) if reg2 < reg3
    /// 2^2 (4) if reg2 == reg3
    Cmp,

    /// reg1 = (reg2) * (reg3)
    Mulf,
    /// reg1 = (reg2) / (reg3)
    Divf,

    /// store result of reg3 * reg4 into registers
    /// reg1 (upper part),
    /// reg2 (lower part),
    ///
    /// arithmetic on unsigned numbers
    ///
    /// reg1, reg2 = reg2 * reg3
    Mul,
    /// store result of reg3 / reg4 in reg1
    /// and reminder in reg2
    ///
    /// arithmetic on unsigned numbers
    ///
    /// reg1 = reg3 / reg4
    /// reg2 = reg3 % reg4
    Div,
    /// store result of reg3 * reg4 into registers
    /// reg1 (upper part),
    /// reg2 (lower part),
    ///
    /// arithmetic on signed numbers
    ///
    /// reg1, reg2 = reg2 * reg3
    Muli,
    /// store result of reg3 / reg4 in reg1
    /// and reminder in reg2
    ///
    /// arithmetic on signed numbers
    ///
    /// reg1 = reg3 / reg4
    /// reg2 = reg3 % reg4
    Divi,
};

fn split_u8(v: u8) [2]u4 {
    return [2]u4{ @as(u4, @truncate(std.math.shr(u8, v, 4))), @as(u4, @truncate(v)) };
}

pub const Instruction = union(OpCode) {
    const Register = RegisterSystem.Register;
    const Reg2 = struct { a: Register, b: Register };
    const Reg3 = struct { a: Register, b: Register, c: Register };
    const Reg4 = struct { a: Register, b: Register, c: Register, d: Register };
    const RegImm = struct { reg: Register, imm: u16 };
    // no args
    Hlt: void,
    Int: void,
    // one register
    Psh: Register,
    Pop: Register,
    Jmp: Register,
    // immediate
    Miu: RegImm,
    Mil: RegImm,
    // 2 regs
    Mov: Reg2,
    Neg: Reg2,
    Not: Reg2,
    Negf: Reg2,
    Itof: Reg2,
    Ftoi: Reg2,
    Rwd: Reg2,
    Wwd: Reg2,
    Jif: Reg2,
    // 3 regs
    Jeq: Reg3,
    Add: Reg3,
    Sub: Reg3,
    Addf: Reg3,
    Subf: Reg3,
    Xor: Reg3,
    Or: Reg3,
    And: Reg3,
    Shl: Reg3,
    Shr: Reg3,
    Cmp: Reg3,
    Mulf: Reg3,
    Divf: Reg3,
    // 4 regs
    Mul: Reg4,
    Div: Reg4,
    Muli: Reg4,
    Divi: Reg4,

    pub fn fromWord(word: u32) !Instruction {
        const bytes: [4]u8 = .{
            // 8 bits opcode
            @intCast((word >> 24) & 0xFF),
            // 24 bits of args
            @intCast((word >> 16) & 0xFF),
            @intCast((word >> 8) & 0xFF),
            @intCast(word & 0xFF),
        };
        // std.log.debug("{any}\n", .{bytes});
        return switch (bytes[0]) {
            0, 1 => |n| no_args: {
                const arg = {};
                break :no_args switch (n) {
                    0 => .{ .Hlt = arg },
                    1 => .{ .Int = arg },
                    else => unreachable,
                };
            },
            2, 3, 4 => |n| single_arg: {
                const halves = split_u8(bytes[1]);
                const register = @as(Register, @enumFromInt(halves[0]));
                break :single_arg switch (n) {
                    2 => .{ .Psh = register },
                    3 => .{ .Pop = register },
                    4 => .{ .Jmp = register },
                    else => unreachable,
                };
            },
            5, 6 => |n| immediate: {
                const halves = split_u8(bytes[1]);
                const register = @as(Register, @enumFromInt(halves[0]));
                const immediate = (@as(u16, @as(u16, bytes[2]) << 8) + @as(u16, bytes[3]));
                break :immediate switch (n) {
                    5 => .{ .Miu = .{ .reg = register, .imm = immediate } },
                    6 => .{ .Mil = .{ .reg = register, .imm = immediate } },
                    else => unreachable,
                };
            },
            7...15 => |n| two_registers: {
                const halves = split_u8(bytes[1]);
                const a = @as(Register, @enumFromInt(halves[0]));
                const b = @as(Register, @enumFromInt(halves[1]));
                const args = Reg2{ .a = a, .b = b };
                break :two_registers switch (n) {
                    7 => .{ .Mov = args },
                    8 => .{ .Neg = args },
                    9 => .{ .Not = args },
                    10 => .{ .Negf = args },
                    11 => .{ .Itof = args },
                    12 => .{ .Ftoi = args },
                    13 => .{ .Rwd = args },
                    14 => .{ .Wwd = args },
                    15 => .{ .Jif = args },
                    else => unreachable,
                };
            },
            16...26 => |n| three_registers: {
                const halves_ab = split_u8(bytes[1]);
                const halves_cd = split_u8(bytes[2]);
                const a = @as(Register, @enumFromInt(halves_ab[0]));
                const b = @as(Register, @enumFromInt(halves_ab[1]));
                const c = @as(Register, @enumFromInt(halves_cd[0]));
                const args = Reg3{ .a = a, .b = b, .c = c };
                break :three_registers switch (n) {
                    16 => .{ .Jeq = args },
                    17 => .{ .Add = args },
                    18 => .{ .Sub = args },
                    29 => .{ .Addf = args },
                    20 => .{ .Subf = args },
                    21 => .{ .Xor = args },
                    22 => .{ .Or = args },
                    23 => .{ .And = args },
                    24 => .{ .Shl = args },
                    25 => .{ .Shr = args },
                    26 => .{ .Cmp = args },
                    27 => .{ .Mulf = args },
                    28 => .{ .Divf = args },
                    else => unreachable,
                };
            },
            29...32 => |n| four_registers: {
                const halves_ab = split_u8(bytes[1]);
                const halves_cd = split_u8(bytes[2]);
                const a = @as(Register, @enumFromInt(halves_ab[0]));
                const b = @as(Register, @enumFromInt(halves_ab[1]));
                const c = @as(Register, @enumFromInt(halves_cd[0]));
                const d = @as(Register, @enumFromInt(halves_cd[1]));
                const args = Reg4{ .a = a, .b = b, .c = c, .d = d };
                break :four_registers switch (n) {
                    29 => .{ .Mul = args },
                    30 => .{ .Div = args },
                    31 => .{ .Muli = args },
                    32 => .{ .Divi = args },
                    else => unreachable,
                };
            },
            else => error.InvalidInstruction,
        };
    }
};
