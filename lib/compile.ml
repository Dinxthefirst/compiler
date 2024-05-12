open Lexer
open Parser
open Evaluator

let compile_and_evaluate input = evaluate (parse (lex input))
