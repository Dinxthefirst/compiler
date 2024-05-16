open Lexer
open Parser
open Evaluator

let compile_and_evaluate : string -> string =
  fun input ->
  Printf.printf "Input:\n%s\n" input;
  let tokens = lex input in
  Printf.printf
    "Tokens:\n%s\n%!"
    (String.concat ", " (List.map Tokens.string_of_token tokens));
  let ast = parse tokens in
  Printf.printf "AST:\n%s\n%!" (Ast.string_of_ast ast);
  Printf.printf "Code:\n%s\n%!" (Ast.pretty_string_of_ast ast);
  let result = evaluate ast in
  result
;;
