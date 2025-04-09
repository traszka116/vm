# vm - A Toy Virtual Machine in Zig

VM is a simple virtual machine implemented in the Zig programming language. It serves as a toy project to explore low-level systems concepts like register-based computation, stack manipulation, memory access, and basic instruction decoding and execution. vm features 16 registers, a customizable memory model, and a small but expressive set of instructions.

## Features

- 16 4-bit registers, including general-purpose and special-purpose types
- Custom instruction set for arithmetic, logic, memory, control flow, and I/O
- Simulated stack and memory system
- Interrupt-based input/output
- Written entirely in Zig for clarity and low-level control
- Program starting from fixed point in memory `0x1000`, which leaves 4096 words of stack memory

## Registers

- **General-purpose**: `RA`–`RD`, `R0`–`R7`
- **Special-purpose**:
  - `SP`: Stack Pointer
  - `RF`: Flags Register (Used to signal invalid behaviours)
  - `IP`: Instruction Pointer
  - `RT`: Timer register (Always contains milliseconds since 01.01.1970)

## Instructions

| Mnemonic | Description |
|----------|-------------|
| `Hlt`    | Halts execution |
| `Int`    | Executes an interrupt (I/O) based on values in RA and RB |
| `Psh`    | Pushes the value in `reg1` onto the stack |
| `Pop`    | Pops a value from the stack into `reg1` |
| `Jmp`    | Jumps to address stored in `reg1` |
| `Mil`    | Sets lower 8 bits of `reg1` with immediate value |
| `Miu`    | Sets upper 8 bits of `reg1` with immediate value |
| `Mov`    | Sets `reg1` to the value of `reg2` |
| `Neg`    | `reg1 = -reg2` |
| `Not`    | `reg1 = ~reg2` |
| `Negf`   | `reg1 = -(float)reg2` |
| `Itof`   | Convert int `reg2` to float and store in `reg1` |
| `Ftoi`   | Convert float `reg2` to int and store in `reg1` |
| `Rwd`    | Reads word from memory at address in `reg2` into `reg1` |
| `Wwd`    | Writes word from `reg2` into memory at address in `reg1` |
| `Jif`    | If `reg1 != 0`, jump to address in `reg2` |
| `Jeq`    | If `reg1 == reg2`, jump to address in `reg3` |
| `Add`    | `reg1 = reg2 + reg3` |
| `Sub`    | `reg1 = reg2 - reg3` |
| `Addf`   | `reg1 = (float)reg2 + (float)reg3` |
| `Subf`   | `reg1 = (float)reg2 - (float)reg3` |
| `Xor`    | `reg1 = reg2 ^ reg3` |
| `Or`     | `reg1 = reg2 | reg3` |
| `And`    | `reg1 = reg2 & reg3` |
| `Shl`    | `reg1 = reg2 << reg3` |
| `Shr`    | `reg1 = reg2 >> reg3` |
| `Cmp`    | Compares `reg2` and `reg3`, sets flags in `reg1`: 1 (GT), 2 (LT), 4 (EQ) |
| `Mulf`   | `reg1 = (float)reg2 * (float)reg3` |
| `Divf`   | `reg1 = (float)reg2 / (float)reg3` |
| `Mul`    | `reg1`, `reg2` = `reg2 * reg3` (unsigned, high/low parts) |
| `Div`    | `reg1 = reg3 / reg4`, `reg2 = reg3 % reg4` (unsigned) |
| `Muli`   | `reg1`, `reg2` = `reg2 * reg3` (signed) |
| `Divi`   | `reg1 = reg3 / reg4`, `reg2 = reg3 % reg4` (signed) |

## Interrupts (`Int` instruction)

The `Int` instruction uses values in registers to perform input/output.

### Mode 0: Console

- `RA = 0` — Console operations

#### Method 0: Input
- `RB = 0`
- `RC` = Memory address to write to
- Reads a line of input from stdin into memory at `RC`
- Resulting length is stored in `RD`

#### Method 1: Output
- `RB = 1`
- `RC` = Memory address of output buffer
- `RD` = Length of data to write
- Writes memory contents to stdout

Invalid interrupt kinds or methods will cause the VM to panic.

## Building

To build and run the project:

```sh
zig build run
```

To only build:

```sh
zig build
```

## Project Structure

```
zigvm/
├── src/
│   ├── main.zig                     # Entry point for the virtual machine
│   └── runtime/
│       ├── instruction.zig         # Opcode definitions and instruction logic
│       ├── memory.zig              # Memory abstraction and manipulation
│       ├── register.zig            # Register implementation
│       ├── runtime.zig             # Core runtime and execution engine
├── build.zig                        # Zig build script
├── build.zig.zon                    # Zig package/project configuration
└── README.md
```


## TODO

- [ ] Add file handling support (open, read, write operations from within the VM)
- [ ] Create a text-based assembler to convert human-readable instructions into bytecode
- [ ] Explore writing a compiler for a simple TAC (three-address code) based language targeting the VM
- [ ] Handle edge cases such as out-of-bounds memory access
- [ ] Eliminate raw `@panic` calls in favor of VM-level exceptions or graceful failure handling

## Dependencies
zig compiler (https://ziglang.org/download/)

## License

MIT License
