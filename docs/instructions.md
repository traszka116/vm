## This is a table of all assembly instructions , along with codes used in binary and description
| code (hex)                   | Mnemonic | Description                                                                            |
| ---------------------------- | -------- | -------------------------------------------------------------------------------------- |
| **0 arguments instructions** |
| 00                           | Hlt      | Halts execution of the program                                                         |
| 01                           | Int      | Performs an interrupt (mostly I/O operations) based on values in `RA` and `RB` registers                 |
| 02                           | Nop      | Does nothing                                                                           |
| **1 arguments instructions** |
| 03                           | Jmp      | Jumps to address stored in `reg1`                                                      |
| 04                           | Psh      | Pushes the value in `reg1` onto the stack                                              |
| 05                           | Pop      | Pops a value from the stack into `reg1`                                                |
| **2 arguments instructions** |
| *2 registers*                |
| 06                           | Mov      | Sets `reg1` to the value of `reg2`                                                     |
| 07                           | Neg      | `reg1 = -reg2`                                                                         |
| 08                           | Not      | `reg1 = ~reg2`                                                                         |
| 09                           | Negf     | `reg1 = -(float)reg2`                                                                  |
| 0A                           | Itof     | Convert int `reg2` to float and store in `reg1`                                        |
| 0B                           | Ftoi     | Convert float `reg2` to int and store in `reg1`                                        |
| 0C                           | Rwd      | Reads word from memory at address in `reg2` into `reg1`                                |
| 0D                           | Wwd      | Writes word from `reg2` into memory at address in `reg1`                               |
| 0E                           | Jif      | If `reg1 != 0`, jump to address in `reg2`                                              |
| *register and immediate*     |
| 0F                           | `Miu`    | Sets upper 16 bits of `reg1` with immediate value                                      |
| 10                           | `Mil`    | Sets lower 16 bits of `reg1` with immediate value                                      |
| **3 arguments instructions** |
| 11                           | `Jeq`    | If `reg1 == reg2`, jump to address in `reg3`                                           |
| 12                           | `Add`    | `reg1 = reg2 + reg3`                                                                   |
| 13                           | `Sub`    | `reg1 = reg2 - reg3`                                                                   |
| 14                           | `Addf`   | `reg1 = (float)reg2 + (float)reg3`                                                     |
| 15                           | `Subf`   | `reg1 = (float)reg2 - (float)reg3`                                                     |
| 16                           | `Xor`    | `reg1 = reg2 ^ reg3`                                                                   |
| 17                           | `Or`     | `reg1 = reg2                                                                           | reg3` |
| 18                           | `And`    | `reg1 = reg2 & reg3`                                                                   | s     |
| 19                           | `Shl`    | `reg1 = reg2 << reg3`                                                                  |
| 1A                           | `Shr`    | `reg1 = reg2 >> reg3`                                                                  |
| 1B                           | `Cmp`    | Compares `reg2` and `reg3`, sets flags in `reg1`: 1 (GT), 2 (LT), 4 (EQ)               |
| 1C                           | `Cmpi`   | Compares as signed int `reg2` and `reg3`, sets flags in `reg1`: 1 (GT), 2 (LT), 4 (EQ) |
| 1D                           | `Cmpf`   | Compares as float `reg2` and `reg3`, sets flags in `reg1`: 1 (GT), 2 (LT), 4 (EQ)      |
| 1E                           | `Mulf`   | `reg1 = (float)reg2 * (float)reg3`                                                     |
| 1F                           | `Divf`   | `reg1 = (float)reg2 / (float)reg3`                                                     |
| 20                           | `Mul`    | `reg1`, `reg2` = `reg2 * reg3` (unsigned, high/low parts)                              |
| 21                           | `Div`    | `reg1 = reg3 / reg4`, `reg2 = reg3 % reg4` (unsigned)                                  |
| 22                           | `Muli`   | `reg1`, `reg2` = `reg2 * reg3` (signed)                                                |
| 23                           | `Divi`   | `reg1 = reg3 / reg4`, `reg2 = reg3 % reg4` (signed)                                    |