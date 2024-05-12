open Lexer
open Parser
open Evaluator

let compile_and_evaulate : string -> string = fun input ->
  let tokens = lex input in
  let ast = parse tokens in
  let result = evaluate ast in
  result