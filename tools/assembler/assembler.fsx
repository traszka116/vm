#r "nuget: FParsec, 1.1.1"
open FParsec

type Key = Key of string
type Value = Value of string
type KeyValue = KeyValue of Key * Value
type Config = Config of KeyValue list

let ws = spaces
let pComment: Parser<unit, unit> = ws >>. pchar ';' >>. restOfLine false |>> ignore

let pConfig: Parser<Config, unit> =
    let pConfigLabel: Parser<unit, unit> = pstring "[Config]" >>. ws |>> ignore

    let pKey: Parser<Key, unit> =
        let isKeyFirstChar c = isLetter c || c = '-' || c = '_'

        let isKeyChar c =
            isLetter c || isDigit c || c = '-' || c = '_'

        many1Satisfy2L isKeyFirstChar isKeyChar "key" |>> Key

    let pValue: Parser<Value, unit> =
        let isValueChar c =
            isLetter c || isDigit c || c = '-' || c = '_' || c = '.'

        many1SatisfyL isValueChar "value" |>> Value

    let pKeyValue: Parser<KeyValue, unit> =
        pKey .>> ws .>> pchar ':' .>> ws .>>. pValue |>> KeyValue

    let pKeyValueLine: Parser<KeyValue option, unit> =
        ws >>. pKeyValue .>> ws .>> opt pComment .>> opt skipNewline |>> Some

    let pOnlyCommentLine: Parser<KeyValue option, unit> =
        ws >>. pComment .>> opt skipNewline >>% None

    let pEmptyLine: Parser<KeyValue option, unit> = ws >>. skipNewline >>% None

    let pLine: Parser<KeyValue option, unit> =
        ws >>. (pKeyValueLine <|> pOnlyCommentLine <|> pEmptyLine)


    ws >>. pConfigLabel >>. ws >>. many pLine |>> (List.choose id >> Config)

let config =
    "
[Config]
stack-size: 1K ; nuts
heap-size: 1M 

name: App

version: 1.0
"

// match run (pConfig .>> eof) config with
// | Success(result, _, _) -> printfn "%A" result
// | Failure(err, _, _) -> printfn "Error: %s" err

let code =
    "
[Code]
set ra, .loop
set r1, .end; end address to r1
set rb, 1; iterator set to 1
set rc, 1; increment set to 1
set rd, 10; end condition set to 10
.loop; begin of loop
    add rb, rb, rc; iterator = iterator + increment
    jeq rb, rd, ra; if met end condition jump to end 
    jmp ra ; jump to ra
    int
.end 
hlt ; pause program
"

type Register =
    | RA
    | RB
    | RC
    | RD
    | R0
    | R1
    | R2
    | R3
    | R4
    | R5
    | R6
    | R7
    | SP
    | RF
    | IP
    | RT

type Opcode0 =
    | Hlt
    | Int
    | Nop

type Instr0 = Opcode0

type Opcode1 =
    | Jmp
    | Psh
    | Pop

type Instr1 = Opcode1 * Register

type OpCode2 =
    | Mov
    | Neg
    | Not
    | Negf
    | Itof
    | Ftoi
    | Rwd
    | Wwd
    | Jif

type Instr2 = OpCode2 * Register * Register

type OpCodeI =
    | Mil
    | Miu

type InstrI = OpCodeI * Register * uint16

type OpCode3 =
    | Jeq
    | Add
    | Sub
    | Addf
    | Subf
    | Xor
    | Or
    | And
    | Shl
    | Shr
    | Cmp
    | Cmpi
    | Cmpf
    | Mulf
    | Divf
    | Mul
    | Div
    | Muli
    | Divi

type Instr3 = OpCode3 * Register * Register * Register

type Instruction =
    | I0 of Instr0
    | I1 of Instr1
    | I2 of Instr2
    | I3 of Instr3
    | Ii of InstrI


let upper_or_lower (x: string) : Parser<string, unit> =
    let u = x.ToUpper()
    let l = x.ToLower()
    pstring u  <|> pstring l 

let pRegister: Parser<Register, unit> =
    choiceL
        [ upper_or_lower "RA" |>> fun _ -> RA
          upper_or_lower "RB" |>> fun _ -> RB
          upper_or_lower "RC" |>> fun _ -> RC
          upper_or_lower "RD" |>> fun _ -> RD
          upper_or_lower "R0" |>> fun _ -> R0
          upper_or_lower "R1" |>> fun _ -> R1
          upper_or_lower "R2" |>> fun _ -> R2
          upper_or_lower "R3" |>> fun _ -> R3
          upper_or_lower "R4" |>> fun _ -> R4
          upper_or_lower "R5" |>> fun _ -> R5
          upper_or_lower "R6" |>> fun _ -> R6
          upper_or_lower "R7" |>> fun _ -> R7
          upper_or_lower "SP" |>> fun _ -> SP
          upper_or_lower "RF" |>> fun _ -> RF
          upper_or_lower "IP" |>> fun _ -> IP
          upper_or_lower "RT" |>> fun _ -> RT ]
        "register literal"

let pImmediate: Parser<uint16, unit> = puint16

let pOpcode0: Parser<Opcode0, unit> =
    choice
        [ upper_or_lower "Hlt" |>> fun _ -> Hlt
          upper_or_lower "Int" |>> fun _ -> Int
          upper_or_lower "Nop" |>> fun _ -> Nop ]

let pOpcode1: Parser<Opcode1, unit> =
    choice
        [
          // uppercase variant
          upper_or_lower "Jmp" |>> fun _ -> Jmp
          upper_or_lower "Psh" |>> fun _ -> Psh
          upper_or_lower "Pop" |>> fun _ -> Pop ]

let pOpcode2: Parser<OpCode2, unit> =
    choice
        [ upper_or_lower "Mov" |>> fun _ -> Mov
          upper_or_lower "Neg" |>> fun _ -> Neg
          upper_or_lower "Not" |>> fun _ -> Not
          upper_or_lower "Negf" |>> fun _ -> Negf
          upper_or_lower "Itof" |>> fun _ -> Itof
          upper_or_lower "Ftoi" |>> fun _ -> Ftoi
          upper_or_lower "Rwd" |>> fun _ -> Rwd
          upper_or_lower "Wwd" |>> fun _ -> Wwd
          upper_or_lower "Jif" |>> fun _ -> Jif ]

let pOpcode3: Parser<OpCode3, unit> =
    choice
        [ upper_or_lower "Jeq" |>> fun _ -> Jeq
          upper_or_lower "Add" |>> fun _ -> Add
          upper_or_lower "Sub" |>> fun _ -> Sub
          upper_or_lower "Addf" |>> fun _ -> Addf
          upper_or_lower "Subf" |>> fun _ -> Subf
          upper_or_lower "Xor" |>> fun _ -> Xor
          upper_or_lower "Or" |>> fun _ -> Or
          upper_or_lower "And" |>> fun _ -> And
          upper_or_lower "Shl" |>> fun _ -> Shl
          upper_or_lower "Shr" |>> fun _ -> Shr
          upper_or_lower "Cmp" |>> fun _ -> Cmp
          upper_or_lower "Cmpi" |>> fun _ -> Cmpi
          upper_or_lower "Cmpf" |>> fun _ -> Cmpf
          upper_or_lower "Mulf" |>> fun _ -> Mulf
          upper_or_lower "Divf" |>> fun _ -> Divf
          upper_or_lower "Mul" |>> fun _ -> Mul
          upper_or_lower "Div" |>> fun _ -> Div
          upper_or_lower "Muli" |>> fun _ -> Muli
          upper_or_lower "Divi" |>> fun _ -> Divi ]

let pOpcodeI: Parser<OpCodeI, unit> =
    (upper_or_lower "Mil" |>> fun _ -> Mil)
    <|> (upper_or_lower "Miu" |>> fun _ -> Miu)

let pInstr0: Parser<Instr0, unit> = pOpcode0 .>> ws

let pInstr1: Parser<Instr1, unit> = pOpcode1 .>> ws .>>. pRegister

let pInstr2: Parser<Instr2, unit> =
    parse {
        let! opcode = pOpcode2
        let! _ = ws
        let! r1 = pRegister
        let! _ = ws >>. pchar ',' .>> ws
        let! r2 = pRegister
        return opcode, r1, r2
    }

let pInstr3: Parser<Instr3, unit> =
    parse {
        let! opcode = pOpcode3
        let! _ = ws
        let! r1 = pRegister
        let! _ = ws >>. pchar ',' .>> ws
        let! r2 = pRegister
        let! _ = ws >>. pchar ',' .>> ws
        let! r3 = pRegister

        return opcode, r1, r2, r3
    }

let pInstrI: Parser<InstrI, unit> =
    parse {
        let! opcode = pOpcodeI
        let! _ = ws
        let! r = pRegister
        let! _ = ws >>. pchar ',' .>> ws
        let! im = pImmediate

        return opcode, r, im
    }

let pInstruction: Parser<Instruction, unit> =
    choiceL
        [ pInstr0 |>> I0
          pInstr1 |>> I1
          pInstr2 |>> I2
          pInstr3 |>> I3
          pInstrI |>> Ii ]
        "instruction"




run (pInstruction .>> eof) "mov ra, rb" |> printfn "%A"
run (pInstruction .>> eof) "add ra, rb, rc" |> printfn "%A"
run (pInstruction .>> eof) "jmp rd" |> printfn "%A"
run (pInstruction .>> eof) "hlt" |> printfn "%A"
run (pInstruction .>> eof) "hltXX" |> printfn "%A"
