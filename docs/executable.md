## this is description of executable file layout



| **Offset** | **Field**        | **Size** | **Description**                                                                             |
| ---------- | ---------------- | -------- | ------------------------------------------------------------------------------------------- |
| `0`        | `magic`          | 4 bytes  | Magic number (file signature) → used to verify it’s a valid executable                      |
| `4`        | `hcode`          | 4 bytes  | Hardware or CPU code (u32, big-endian) identifying target architecture                      |
| `8`        | `stack_size`     | 4 bytes  | Size of the program’s stack (in bytes or words, defined by system)                          |
| `12`       | `program_size`   | 4 bytes  | Size of the program (code) segment                                                          |
| `16`       | `static_size`    | 4 bytes  | Size of the static data segment                                                             |
| `20`       | `heap_size`      | 4 bytes  | Size of the heap segment                                                                    |
| `24`       | `entry_point`    | 4 bytes  | Entry point address (instruction pointer where execution starts)                            |
| `28`       | `reserved`       | 16 bytes | Reserved for future use (padding, future extensions)                                        |
| `44`       | **Program Data** | variable | Raw program data: instructions, static data, heap (exists in memory layout but not in file) |

