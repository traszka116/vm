const Memory = @This();
data: []u32,
pub fn readWord(self: Memory, address: u32) u32 {
    return self.data[address];
}
pub fn writeWord(self: Memory, address: u32, value: u32) void {
    self.data[address] = value;
}
