const std = @import("std");
const enums = std.enums;

const RegisterSystem = @This();

pub const Register = enum(u4) {
    /// general usage register a
    RA,
    /// general usage register b
    RB,
    /// general usage register c
    RC,
    /// general usage register d
    RD,
    /// general usage register 0
    R0,
    /// general usage register 1
    R1,
    /// general usage register 2
    R2,
    /// general usage register 3
    R3,
    /// general usage register 4
    R4,
    /// general usage register 5
    R5,
    /// general usage register 6
    R6,
    /// general usage register 7
    R7,
    /// stack pointer
    SP,
    /// flag register
    RF,
    /// instruction pointer
    IP,
    /// timer register
    RT,
};
pub const Flag = enum(u5) {
    stack_overflow = 0,
    division_by_zero,
    out_of_memory,
    overflow,
};

registers: [enums.values(Register).len]u32 = undefined,
pub fn register_get(self: RegisterSystem, register: Register) u32 {
    if (register == .RT) {
        return @as(u32, @truncate(@as(u64, @bitCast(std.time.milliTimestamp()))));
    }
    return self.registers[@intFromEnum(register)];
}
pub fn register_set(self: *RegisterSystem, register: Register, value: u32) void {
    self.registers[@intFromEnum(register)] = value;
}
pub fn register_set_high_half(self: *RegisterSystem, register: Register, value: u16) void {
    const mask: u32 = 0x0000ffff;
    const update_with = @as(u32, value) << 16;
    const old_value = self.register_get(register);
    const new_value = (old_value & mask) | update_with;
    self.register_set(register, new_value);
}
pub fn register_set_low_half(self: *RegisterSystem, register: Register, value: u16) void {
    const mask: u32 = 0xffff0000;
    const update_with = @as(u32, value);
    const old_value = self.register_get(register);
    const new_value = (old_value & mask) | update_with;
    self.register_set(register, new_value);
}
pub fn set_flag(self: *RegisterSystem, flag: Flag, val: u1) void {
    const flags = self.register_get(.RF);
    const mask = @as(u32, std.math.shl(u32, 1, @as(u5, @intFromEnum(flag))));
    const new_value = (flags & ~mask) | (mask * val);
    self.register_set(.RF, new_value);
}
