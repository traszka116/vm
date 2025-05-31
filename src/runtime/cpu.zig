const std = @import("std");
const RegisterSystem = @import("register.zig");
const Memory = @import("memory.zig");
const instr = @import("instruction.zig");
const enums = std.enums;
const Register = RegisterSystem.Register;
const Instruction = instr.Instruction;

const Self = @This();
const Effect = union(enum) {
    None,
    Halt,
    Interrupt,
    Jump: struct { into: u32 },
    MemoryRead: struct { addr: u32, into: Register },
    MemoryWrite: struct { ptr: u32, val: u32 },
    Push: struct { value: u32 },
    Pop: struct { into: Register },
    Assign: struct { reg: Register, value: u32 },
};

registers: RegisterSystem,
running: bool = false,

pub fn run_instruction(self: *Self, instruction: Instruction, memory: *Memory) Effect {
    // figure out effect of instruction
    const effect = self.eval(instruction);
    // execute the effect
    effect_dispatch(effect, self, memory);
    // move to next instruction, or not depending on type of instruction
    switch (effect) {
        .Halt, .Jump => {},
        else => blk: {
            const ip = self.registers.register_get(.IP);
            self.registers.register_set(.IP, ip + 1);
            break :blk true;
        },
    }
    // return effect given
    return effect;
}
fn effect_dispatch(effect: Effect, cpu: *Self, mem: *Memory) void {
    switch (effect) {
        .None => {},
        .Halt => cpu.running = false,
        .Assign => |a| cpu.register.register_set(a.reg, a.value),
        .MemoryRead => |a| cpu.registers.register_set(a.into, mem.readWord(a.addr)),
        .MemoryWrite => |a| mem.writeWord(a.ptr, a.val),
        .Jump => |a| cpu.registers.register_set(Register.IP, a.into),
        .Push => |a| {
            const sp = cpu.registers.register_get(.SP);
            const new_sp = sp - 1;
            mem.writeWord(new_sp, a.value);
            cpu.registers.register_set(.SP, new_sp);
        },
        .Pop => |a| {
            const sp = cpu.registers.register_get(.SP);
            const new_sp = sp + 1;
            const val = mem.readWord(sp);
            cpu.registers.register_set(a.into, val);
            cpu.registers.register_set(.SP, new_sp);
        },
    }
}
fn eval(self: *Self, instruction: Instruction) Effect {
    return switch (instruction) {
        .i0 => |v| self.eval_i0(v),
        .i1 => |v| self.eval_i1(v),
        .i2 => |v| self.eval_i2(v),
        .i3 => |v| self.eval_i3(v),
        .im => |v| self.eval_im(v),
    };
}

fn eval_i0(self: Self, i: instr.Instr0) Effect {
    _ = self;
    return switch (i.op) {
        .ctl => switch (i.op.ctl) {
            .Hlt => hlt(),
            .Int => int(),
            .Nop => nop(),
        },
    };
}
fn hlt() Effect {
    return .Halt;
}
fn int() Effect {
    return .None;
}
fn nop() Effect {
    return .None;
}

fn eval_i1(self: Self, i: instr.Instr1) Effect {
    return switch (i.op) {
        .ctl => switch (i.op.ctl) {
            .Jmp => jmp(i.arg.arg, self),
            .Pop => pop(i.arg.arg, self),
            .Psh => psh(i.arg.arg, self),
        },
    };
}
fn jmp(register: Register, self: Self) Effect {
    const jump_to = self.registers.register_get(register);
    return .{ .Jump = .{ .into = jump_to } };
}
fn pop(register: Register, _: Self) Effect {
    return .{ .Pop = .{ .into = register } };
}
fn psh(register: Register, self: Self) Effect {
    return .{ .Push = .{ .value = self.registers.register_get(register) } };
}

fn eval_i2(self: Self, i: instr.Instr2) Effect {
    return switch (i.op) {
        .ctl => switch (i.op.ctl) {
            .Jif => jif(i.arg.arg1, i.arg.arg2, self),
            .Rwd => rwd(i.arg.arg1, i.arg.arg2, self),
            .Wwd => wwd(i.arg.arg1, i.arg.arg2, self),
        },
        .alu => switch (i.op.alu) {
            .Ftoi => ftoi(i.arg.arg1, i.arg.arg2, self),
            .Itof => itof(i.arg.arg1, i.arg.arg2, self),
            .Mov => mov(i.arg.arg1, i.arg.arg2, self),
            .Neg => neg(i.arg.arg1, i.arg.arg2, self),
            .Negf => negf(i.arg.arg1, i.arg.arg2, self),
            .Not => not(i.arg.arg1, i.arg.arg2, self),
        },
    };
}
fn jif(a: Register, b: Register, self: Self) Effect {
    const val = self.registers.register_get(a);
    const addr = self.registers.register_get(b);
    return if (val == 0) .None else .{ .Jump = .{ .into = addr } };
}
fn rwd(a: Register, b: Register, self: Self) Effect {
    const addr = self.registers.register_get(b);
    return .{ .MemoryRead = .{ .addr = addr, .into = a } };
}
fn wwd(a: Register, b: Register, self: Self) Effect {
    const addr = self.registers.register_get(a);
    const value = self.registers.register_get(b);

    return .{ .MemoryWrite = .{ .ptr = addr, .val = value } };
}
fn ftoi(a: Register, b: Register, self: Self) Effect {
    const val = self.registers.register_get(b);
    const fval = @as(f32, @bitCast(val));
    const ival = @as(u32, @intFromFloat(fval));
    return .{ .Assign = .{ .reg = a, .value = ival } };
}
fn itof(a: Register, b: Register, self: Self) Effect {
    const val = self.registers.register_get(b);
    const fval = @as(f32, @floatFromInt(val));
    return .{ .Assign = .{ .reg = a, .value = fval } };
}
fn mov(a: Register, b: Register, self: Self) Effect {
    const val = self.registers.register_get(b);
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn neg(a: Register, b: Register, self: Self) Effect {
    const val = self.registers.register_get(b);
    const ival = @as(i32, @bitCast(val));
    const neg_val = -ival;
    return .{ .Assign = .{ .reg = a, .value = neg_val } };
}
fn negf(a: Register, b: Register, self: Self) Effect {
    const val = self.registers.register_get(b);
    const fval = @as(f32, @bitCast(val));
    const neg_val = -fval;
    const ival = @as(u32, @bitCast(neg_val));
    return .{ .Assign = .{ .reg = a, .value = ival } };
}
fn not(a: Register, b: Register, self: Self) Effect {
    const value = self.registers.register_get(b);
    const notted = @bitReverse(value);
    return .{ .Assign = .{ .reg = a, .value = notted } };
}

fn eval_i3(self: Self, i: instr.Instr3) Effect {
    return switch (i.op) {
        .ctl => switch (i.op.ctl) {
            .Jeq => jeq(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
        },
        .alu => switch (i.op.alu) {
            .Add => add(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Addf => addf(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .And => @"and"(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Cmp => cmp(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Cmpi => cmpi(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Cmpf => cmpf(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Div => div(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Divf => divf(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Divi => divi(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Mul => mul(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Mulf => mulf(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Muli => muli(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Or => @"or"(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Shl => shl(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Shr => shr(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Sub => sub(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Subf => subf(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
            .Xor => xor(i.arg.arg1, i.arg.arg2, i.arg.arg3, self),
        },
    };
}
fn jeq(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(a);
    const val2 = self.registers.register_get(b);
    const addr = self.registers.register_get(c);
    return if (val1 != val2) .None else .{ .Jump = .{ .into = addr } };
}
fn add(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 + val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn addf(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(f32, @bitCast(val1));
    const val2f = @as(f32, @bitCast(val2));
    const resultf = val1f + val2f;
    const val = @as(u32, @bitCast(resultf));
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn @"and"(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 & val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn cmp(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const order = std.math.order(val1, val2);
    const result = @as(u32, switch (order) {
        .gt => 1,
        .lt => 2,
        .eq => 4,
    });

    return .{ .Assign = .{ .reg = a, .value = result } };
}
fn cmpi(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1i = @as(i32, @bitCast(val1));
    const val2i = @as(i32, @bitCast(val2));
    const order = std.math.order(val1i, val2i);
    const result = @as(u32, switch (order) {
        .gt => 1,
        .lt => 2,
        .eq => 4,
    });

    return .{ .Assign = .{ .reg = a, .value = result } };
}
fn cmpf(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(i32, @bitCast(val1));
    const val2f = @as(i32, @bitCast(val2));
    const order = std.math.order(val1f, val2f);
    const result = @as(u32, switch (order) {
        .gt => 1,
        .lt => 2,
        .eq => 4,
    });

    return .{ .Assign = .{ .reg = a, .value = result } };
}
fn div(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 / val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn divf(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(f32, @bitCast(val1));
    const val2f = @as(f32, @bitCast(val2));
    const resultf = val1f / val2f;
    const val = @as(u32, @bitCast(resultf));
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn divi(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(i32, @bitCast(val1));
    const val2f = @as(i32, @bitCast(val2));
    const resultf = val1f / val2f;
    const val = @as(u32, @bitCast(resultf));
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn mul(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 * val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn mulf(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(f32, @bitCast(val1));
    const val2f = @as(f32, @bitCast(val2));
    const resultf = val1f * val2f;
    const val = @as(u32, @bitCast(resultf));
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn muli(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(i32, @bitCast(val1));
    const val2f = @as(i32, @bitCast(val2));
    const resultf = val1f * val2f;
    const val = @as(u32, @bitCast(resultf));
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn @"or"(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 | val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn shl(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = std.math.shl(u32, val1, val2);
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn shr(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = std.math.shr(u32, val1, val2);
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn sub(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 - val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn subf(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val1f = @as(f32, @bitCast(val1));
    const val2f = @as(f32, @bitCast(val2));
    const resultf = val1f - val2f;
    const val = @as(u32, @bitCast(resultf));
    return .{ .Assign = .{ .reg = a, .value = val } };
}
fn xor(a: Register, b: Register, c: Register, self: Self) Effect {
    const val1 = self.registers.register_get(b);
    const val2 = self.registers.register_get(c);
    const val = val1 ^ val2;
    return .{ .Assign = .{ .reg = a, .value = val } };
}

fn eval_im(self: Self, i: instr.InstrImm) Effect {
    return switch (i.op) {
        .alu => switch (i.op.alu) {
            .Mil => mil(i.arg.reg, i.arg.imm, self),
            .Miu => miu(i.arg.reg, i.arg.imm, self),
        },
    };
}
fn mil(reg: Register, imm: u16, self: Self) Effect {
    const val = self.registers.register_get(reg);
    const mask: u32 = 0xffff0000;
    const new_val = (val & mask) | @as(u32, imm);
    return .{ .Assign = .{ .reg = reg, .value = new_val } };
}
fn miu(reg: Register, imm: u16, self: Self) Effect {
    const val = self.registers.register_get(reg);
    const mask: u32 = 0x0000ffff;
    const new_val = (val & mask) | (@as(u32, imm) << 16);
    return .{ .Assign = .{ .reg = reg, .value = new_val } };
}
