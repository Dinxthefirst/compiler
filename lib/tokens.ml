type token =
  | INT of int
  | VAR of string
  | BOOL of bool
  | DECLARATION
  | ASSIGNMENT
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE
  | MODULO
  | BANG
  | IF
  | THEN
  | ELSE
  | EQ
  | NEQ
  | LT
  | LTEQ
  | LBRACE
  | RBRACE
  | LPAREN
  | RPAREN
  | SEMICOLON
  | EOF

let string_of_token = function
  | INT i -> "INT " ^ string_of_int i
  | VAR s -> "VAR " ^ s
  | BOOL b -> "BOOL " ^ string_of_bool b
  | DECLARATION -> "DECLARATION"
  | ASSIGNMENT -> "ASSIGNMENT"
  | PLUS -> "PLUS"
  | MINUS -> "MINUS"
  | TIMES -> "TIMES"
  | DIVIDE -> "DIVIDE"
  | MODULO -> "MODULO"
  | BANG -> "BANG"
  | IF -> "IF"
  | THEN -> "THEN"
  | ELSE -> "ELSE"
  | EQ -> "EQ"
  | NEQ -> "NEQ"
  | LT -> "LT"
  | LTEQ -> "LTEQ"
  | LBRACE -> "LBRACE"
  | RBRACE -> "RBRACE"
  | LPAREN -> "LPAREN"
  | RPAREN -> "RPAREN"
  | SEMICOLON -> "SEMICOLON"
  | EOF -> "EOF"
;;
