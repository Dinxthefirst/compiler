type token =
  | INT of int
  | VAR of string
  | DECLARATION
  | ASSIGNMENT
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE
  | MODULO
  | LBRACE
  | RBRACE
  | LPAREN
  | RPAREN
  | SEMICOLON
  | EOF

let string_of_token = function
  | INT i -> "INT " ^ string_of_int i
  | VAR s -> "VAR " ^ s
  | DECLARATION -> "DECLARATION"
  | ASSIGNMENT -> "ASSIGNMENT"
  | PLUS -> "PLUS"
  | MINUS -> "MINUS"
  | TIMES -> "TIMES"
  | DIVIDE -> "DIVIDE"
  | MODULO -> "MODULO"
  | LBRACE -> "LBRACE"
  | RBRACE -> "RBRACE"
  | LPAREN -> "LPAREN"
  | RPAREN -> "RPAREN"
  | SEMICOLON -> "SEMICOLON"
  | EOF -> "EOF"
;;
