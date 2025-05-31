## This is table of interrups

| **mode (RA)**         | **command (RB)** | **Name**    | **Description**                                                                                        |
| --------------------- | ---------------- | ----------- | ------------------------------------------------------------------------------------------------------ |
| console mode (RA = 0) |
| 0                     | 0                | write_str   | Write a string from memory to stdout. RC = memory address (word index), RD = length (bytes).           |
| 0                     | 1                | write_char  | Write a single character (byte) to stdout. RC = byte value.                                            |
| 0                     | 2                | read_char   | Read a single character (byte) from stdin, store result in RC.                                         |
| 0                     | 3                | read_str    | Read a string from stdin into memory; update RD with actual bytes read. RC = address, RD = max length. |
| 0                     | 4                | write_int   | Write signed 32-bit integer (from RC) to stdout. RC holds signed int (bit-cast from u32).              |
| 0                     | 5                | write_uint  | Write unsigned 32-bit integer (from RC) to stdout. RC holds unsigned int.                              |
| 0                     | 6                | write_float | Write 32-bit float (from RC) to stdout. RC holds float value (bit-cast from u32).                      |
| 0                     | 7                | read_int    | Read signed 32-bit integer from stdin, store result (bit-cast) in RC.                                  |
| 0                     | 8                | read_uint   | Read unsigned 32-bit integer from stdin, store result in RC.                                           |
| 0                     | 9                | read_float  | Read 32-bit float from stdin, store result (bit-cast) in RC.                                           |
