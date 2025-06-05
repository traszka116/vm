module Config 
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