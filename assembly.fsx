open System
open System.Text.RegularExpressions

let code =
    """
    section: meta
    stack_size: 4096 ; set stacksize to 4096
    memory_size: 1048576 ; set memory to 1MB

    section: text
    set ra, .loop
    set r1, .end; end address to r1
    set rb, 1; iterator set to 1
    set rc, 1; increment set to 1
    set rd, 10; end condition set to 10
    .loop; begin of loop
    add rb, rb, rc; iterator = iterator + increment
    jeq rb, rd, ra; if met end condition jump to end 
    jmp ra ; jump to ra
    .end 
    hlt ; pause program
    
    section: data
    str .y: "test with ; character" ; zero ended string
    str .y: "test with ; character" 
    byte .z: 10, 11 ; array of bytes
    byte .x: 11 ; single byte value
    val .i: 600, 12 ; array of 32bit values (int/float)
    val .j: 77 ; single 32 bit value
    mem .blk: 11 ; array of 9 bytes 
    """

let code_no_comments =
    code.Split '\n'
    |> Array.map (fun x ->
        match x with
        | str when str.Trim().StartsWith "str" ->
            let idx = str.LastIndexOf '"'

            if idx = -1 then
                raise (Exception "expected some sort of string")

            str.Substring(0, idx + 1).Trim()
        | _ -> ((x.Split ';')[0]).Trim())
    |> Array.filter (String.IsNullOrWhiteSpace >> not)
    |> String.concat "\n"

let sections =
    code_no_comments.Split "section:"
    |> Seq.ofArray
    |> Seq.filter (String.IsNullOrWhiteSpace >> not)
    |> Seq.map (fun text ->
        let label_to = text.IndexOf '\n'

        if label_to = -1 then
            raise (Exception "Section must have label")

        text.Substring(0, label_to).Trim(), (text.Substring label_to).Trim())
    |> Map.ofSeq

let metadata =
    (sections |> Map.tryFind "meta" |> Option.orElse (Some "") |> Option.get).Split "\n"
    |> Seq.map (fun x ->
        let key_to = x.IndexOf ':'

        if key_to = -1 then
            raise (Exception "metadata is in 'key: value' format")

        let key = x.Substring(0, key_to).Trim()
        let value = x.Substring(key_to + 1).Trim()
        key, value)
    |> Map.ofSeq

let stack_size =
    metadata
    |> Map.tryFind "stack_size"
    |> Option.orElse (Some "4096")
    |> Option.get
    |> Int32.Parse


let data =
    let parseUint8 b = uint8 (UInt16.Parse b)

    let parseNumber (s: string) : uint32 option =
        let parseHex (s: string) : uint32 option =
            match Int32.TryParse(s, Globalization.NumberStyles.HexNumber, null) with
            | true, value -> Some(uint32 value)
            | false, _ -> None

        let parseFloat (s: string) : uint32 option =
            match Single.TryParse s with
            | true, value -> Some(value |> BitConverter.GetBytes |> BitConverter.ToUInt32)
            | false, _ -> None

        let parseInt (s: string) : uint32 option =
            match Int32.TryParse s with
            | true, value -> Some(uint32 value)
            | false, _ -> None

        parseInt s |> Option.orElse (parseFloat s) |> Option.orElse (parseHex s)

    let splitUint32 (s: uint32) =
        if BitConverter.IsLittleEndian then
            BitConverter.GetBytes s |> Array.rev
        else
            BitConverter.GetBytes s

    let list, _ =
        (sections |> Map.tryFind "data" |> Option.orElse (Some "") |> Option.get).Split '\n'
        |> Seq.map (fun x ->
            let name_start = x.IndexOf '.'
            let name_end = x.IndexOf ':'
            let name = (x.Substring(name_start, name_end - name_start)).Trim()
            let kind = (x.Substring(0, name_start)).Trim()
            let values = (x.Substring(name_end + 1)).Trim()

            name,
            match kind, values with
            | "str", s -> s.Substring(1, values.Length - 2).AsSpan().ToArray() |> Array.map uint8
            | "byte", b when b.Contains ',' ->
                b.Split [| ','; ' ' |]
                |> Array.filter (String.IsNullOrWhiteSpace >> not)
                |> Array.map parseUint8
            | "byte", b -> [| parseUint8 (b.Trim()) |]
            | "val", v when v.Contains ',' ->
                v.Split [| ','; ' ' |]
                |> Array.filter (String.IsNullOrWhiteSpace >> not)
                |> Array.map (parseNumber >> Option.get)
                |> Array.collect splitUint32
            | "val", v -> v.Trim() |> parseNumber |> Option.get |> splitUint32
            | "mem", b -> Array.replicate (int (parseNumber b).Value) 0uy
            | _ -> [||])
        |> Array.ofSeq
        |> Array.mapFold (fun offset (name, array) -> (name, (array, offset)), offset + array.Length) 0

    list |> Map.ofArray

let text =
    (sections |> Map.tryFind "text" |> Option.orElse (Some "") |> Option.get).Split '\n'

let program_len =
    text
    |> Array.fold
        (fun (i) s ->
            match s with
            | l when l.StartsWith '.' -> i
            | c when c.StartsWith "set" -> i + 2
            | _ -> i + 1)
        0

let labels, _ =
    text
    |> Seq.fold
        (fun (accLabels, pos) text ->
            match text with
            | i when i.StartsWith "set" -> accLabels, pos + 2
            | l when l.StartsWith '.' -> Map.add l pos accLabels, pos
            | _ -> accLabels, pos + 1)
        (Map.empty<string, int>, stack_size)

let offsets = data |> Map.map (fun _ (_, i) -> i + program_len)

let parseNumber (s: string) : uint32 option =
    let parseHex (s: string) : uint32 option =
        match Int32.TryParse(s, Globalization.NumberStyles.HexNumber, null) with
        | true, value -> Some(uint32 value)
        | false, _ -> None

    let parseFloat (s: string) : uint32 option =
        match Single.TryParse s with
        | true, value -> Some(value |> BitConverter.GetBytes |> BitConverter.ToUInt32)
        | false, _ -> None

    let parseInt (s: string) : uint32 option =
        match Int32.TryParse s with
        | true, value -> Some(uint32 value)
        | false, _ -> None

    parseInt s |> Option.orElse (parseFloat s) |> Option.orElse (parseHex s)

let parseHex16 (s: string) : uint16 =
    UInt16.Parse(s, Globalization.NumberStyles.HexNumber)

let splitUInt32 (value: uint32) : uint16 * uint16 =
    let high = uint16 (value >>> 16)
    let low = uint16 (value &&& 0xFFFFu)
    (high, low)


let decomposed =
    text
    |> Array.filter (fun x -> Regex.IsMatch(x, @"^\.[a-zA-Z][a-zA-Z0-9_]*") |> not)
    |> Array.map (fun x -> x.Split [| ' '; ',' |] |> Array.filter (String.IsNullOrWhiteSpace >> not))
    |> Array.map (fun arr ->
        arr
        |> Array.map (function
            | label when Regex.IsMatch(label, @"^\.[a-zA-Z][a-zA-Z0-9_]*") ->
                labels.TryFind label
                |> Option.orElse (offsets.TryFind label)
                |> Option.get
                |> string
            | x -> x))
    |> Array.map (fun arr ->
        let opcode = arr[0]
        let args = arr[1..]

        match opcode, args with
        | "set", args ->
            let high, low = splitUInt32 (parseNumber args[1] |> Option.get)

            [| [| "mil"; args[0]; sprintf "%X" low |]
               [| "miu"; args[0]; sprintf "%X" high |] |]
        | _ -> [| arr |])
    |> Array.collect id

let registerNumber (reg: string) : uint8 =
    match reg.ToLower() with
    | "ra" -> uint8 0x00
    | "rb" -> uint8 0x01
    | "rc" -> uint8 0x02
    | "rd" -> uint8 0x03
    | "r0" -> uint8 0x04
    | "r1" -> uint8 0x05
    | "r2" -> uint8 0x06
    | "r3" -> uint8 0x07
    | "r4" -> uint8 0x08
    | "r5" -> uint8 0x09
    | "r6" -> uint8 0x0A
    | "r7" -> uint8 0x0B
    | "sp" -> uint8 0x0C
    | "rf" -> uint8 0x0D
    | "ip" -> uint8 0x0E
    | "rt" -> uint8 0x0F
    | _ -> raise (Exception "Invalid register")

let opCodeNumber (opcode: string) : uint8 =
    match opcode.ToLower() with
    | "hlt" -> uint8 0
    | "int" -> uint8 1
    | "psh" -> uint8 2
    | "pop" -> uint8 3
    | "jmp" -> uint8 4
    | "miu" -> uint8 5
    | "mil" -> uint8 6
    | "mov" -> uint8 7
    | "neg" -> uint8 8
    | "not" -> uint8 9
    | "negf" -> uint8 10
    | "itof" -> uint8 11
    | "ftoi" -> uint8 12
    | "rwd" -> uint8 13
    | "wwd" -> uint8 14
    | "jif" -> uint8 15
    | "jeq" -> uint8 16
    | "add" -> uint8 17
    | "sub" -> uint8 18
    | "addf" -> uint8 19
    | "subf" -> uint8 20
    | "xor" -> uint8 21
    | "or" -> uint8 22
    | "and" -> uint8 23
    | "shl" -> uint8 24
    | "shr" -> uint8 25
    | "cmp" -> uint8 26
    | "mulf" -> uint8 27
    | "divf" -> uint8 28
    | "mul" -> uint8 29
    | "div" -> uint8 30
    | "muli" -> uint8 31
    | "divi" -> uint8 32
    | _ -> raise (Exception "Invalid opcode")

let numeric =
    decomposed
    |> Array.map (fun instr ->
        let opcode = opCodeNumber instr[0]
        let args = instr[1..]

        opcode,
        match instr[0] with
        | "hlt" -> [||]
        | "int" -> [||]
        | "psh" -> [| uint16 (registerNumber args[0]) |]
        | "pop" -> [| uint16 (registerNumber args[0]) |]
        | "jmp" -> [| uint16 (registerNumber args[0]) |]
        | "miu" -> [| uint16 (registerNumber args[0]); parseHex16 args[1] |]
        | "mil" -> [| uint16 (registerNumber args[0]); parseHex16 args[1] |]
        | "mov" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "neg" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "not" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "negf" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "itof" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "ftoi" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "rwd" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "wwd" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "jif" -> [| uint16 (registerNumber args[0]); uint16 (registerNumber args[1]) |]
        | "jeq" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "add" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "sub" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "addf" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "subf" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "xor" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "or" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "and" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "shl" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "shr" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "cmp" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "mulf" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "divf" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2]) |]
        | "mul" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2])
               uint16 (registerNumber args[3]) |]
        | "div" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2])
               uint16 (registerNumber args[3]) |]
        | "muli" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2])
               uint16 (registerNumber args[3]) |]
        | "divi" ->
            [| uint16 (registerNumber args[0])
               uint16 (registerNumber args[1])
               uint16 (registerNumber args[2])
               uint16 (registerNumber args[3]) |]
        | _ -> raise (Exception "Invalid opcode"))

let instructions =
    numeric
    |> Seq.map (function
        | op, [||] -> uint32 op <<< 24
        | op, [| a |] -> uint32 op <<< 24 ||| (uint32 a <<< 20)
        | op, [| a; imm |] when [| uint8 5; uint8 6 |] |> Array.contains op ->
            uint32 op <<< 24 ||| (uint32 a <<< 20) ||| uint32 imm
        | op, [| a; b |] -> uint32 op <<< 24 ||| (uint32 a <<< 20) ||| (uint32 b <<< 16)
        | op, [| a; b; c |] ->
            uint32 op <<< 24
            ||| (uint32 a <<< 20)
            ||| (uint32 b <<< 16)
            ||| (uint32 c <<< 12)
        | op, [| a; b; c; d |] ->
            uint32 op <<< 24
            ||| (uint32 a <<< 20)
            ||| (uint32 b <<< 16)
            ||| (uint32 c <<< 12)
            ||| (uint32 d <<< 8)

        | _ -> raise (Exception "Invalid instruction"))

let bytecode =
    instructions
    |> Seq.map (fun x ->
        if BitConverter.IsLittleEndian then
            BitConverter.GetBytes x |> Array.rev
        else
            BitConverter.GetBytes x)
    |> Seq.collect id

let bytesUint32 (x: uint32) =
    if BitConverter.IsLittleEndian then
        BitConverter.GetBytes x |> Array.rev
    else
        BitConverter.GetBytes x

let meta =
    let meta_stack =
        metadata
        |> Map.tryFind "stack_size"
        |> Option.orElse (Some "4096")
        |> Option.get
        |> UInt32.Parse
        |> bytesUint32

    let meta_mem =
        metadata
        |> Map.tryFind "memory_size"
        |> Option.orElse (Some "1048576")
        |> Option.get
        |> UInt32.Parse
        |> bytesUint32

    Seq.concat [ meta_mem; meta_stack ]

let variables =
    let values =
        data
        |> Map.toSeq
        |> Seq.map (fun (_, v) -> v)
        |> Seq.sortBy (fun (_, o) -> o)
        |> Seq.map (fun (d, _) -> d)
        |> Seq.collect id

    let len = Seq.length values

    let padding_len = (4 - len % 4) % 4


    Seq.concat [ values; Seq.replicate padding_len 0uy ]

let result = Seq.concat [ meta; bytecode; variables ] |> Array.ofSeq

IO.File.WriteAllBytes("code.bin", result)
