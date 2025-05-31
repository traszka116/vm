# vm - A Toy Virtual Machine in Zig

VM is a simple virtual machine implemented in the Zig programming language. It serves as a toy project to explore low-level systems concepts like register-based computation, stack manipulation, memory access, and basic instruction decoding and execution. vm features 16 registers, a customizable memory model, and a small but expressive set of instructions.

## Features
- 16 32bit registers, including general-purpose and special-purpose types
- Custom instruction set for arithmetic, logic, memory, control flow, and I/O
- Simulated stack and memory system
- Interrupt-based input/output
- Written entirely in Zig for clarity and low-level control
- Program starting from arbitrary point based on binary file header

## VM TODO
- [ ] Add file handling support (open, read, write operations from within the VM)
- [ ] Add networking support
- [ ] Add simd support
- [ ] Add error handling on VM level
- [ ] Handle edge cases such as out-of-bounds memory access
- [ ] Modify reader to load part of executable at a time


## VM Dependencies
zig compiler (0.14.0) (https://ziglang.org/download/)

# Assembler Dependencies

dotnet (9.0.2) (https://dotnet.microsoft.com/en-us/download/)

FParsec (1.1.1) (https://www.nuget.org/packages/fparsec/)



## License
MIT License
