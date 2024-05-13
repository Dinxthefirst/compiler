open Lexer
open Parser
open Evaluator

let compile_and_evaluate : string -> string =
  fun input ->
  let tokens = lex input in
  let ast = parse tokens in
  Printf.printf "AST:\n%s\n" (Ast.string_of_ast ast);
  Printf.printf "Code:\n%s\n" (Ast.pretty_string_of_ast ast);
  let result = evaluate ast in
  result
;;
