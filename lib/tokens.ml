type token =
  | INT of int
  | VAR of string
  | BOOL of bool
  | LET
  | FUNCTION
  | ASSIGNMENT
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE
  | MODULO
  | POWER
  | BANG
  | IF
  | THEN
  | ELSE
  | EQ
  | NEQ
  | LT
  | LTEQ
  | GT
  | GTEQ
  | AND
  | OR
  | LBRACE
  | RBRACE
  | LPAREN
  | RPAREN
  | SEMICOLON
  | ARROW
  | MATCH
  | WITH
  | CASE
  | ILLEGAL
  | EOF

let string_of_token = function
  | INT i -> "INT " ^ string_of_int i
  | VAR s -> "VAR " ^ s
  | BOOL b -> "BOOL " ^ string_of_bool b
  | LET -> "LET"
  | FUNCTION -> "FUNCTION"
  | ASSIGNMENT -> "ASSIGNMENT"
  | PLUS -> "PLUS"
  | MINUS -> "MINUS"
  | TIMES -> "TIMES"
  | DIVIDE -> "DIVIDE"
  | MODULO -> "MODULO"
  | POWER -> "POWER"
  | BANG -> "BANG"
  | IF -> "IF"
  | THEN -> "THEN"
  | ELSE -> "ELSE"
  | EQ -> "EQ"
  | NEQ -> "NEQ"
  | LT -> "LT"
  | LTEQ -> "LTEQ"
  | GT -> "GT"
  | GTEQ -> "GTEQ"
  | AND -> "AND"
  | OR -> "OR"
  | LBRACE -> "LBRACE"
  | RBRACE -> "RBRACE"
  | LPAREN -> "LPAREN"
  | RPAREN -> "RPAREN"
  | SEMICOLON -> "SEMICOLON"
  | ARROW -> "ARROW"
  | MATCH -> "MATCH"
  | WITH -> "WITH"
  | CASE -> "CASE"
  | ILLEGAL -> "ILLEGAL"
  | EOF -> "EOF"
;;

let rec string_of_tokens = function
  | [] -> ""
  | t :: ts -> string_of_token t ^ " " ^ string_of_tokens ts
;;
