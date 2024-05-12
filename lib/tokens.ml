type token =
  | INT of int
  | PLUS
  | MINUS
  | TIMES
  | DIVIDE
  | LPAREN
  | RPAREN
  | EOF

let string_of_token = function
  | INT i -> "INT " ^ string_of_int i
  | PLUS -> "PLUS"
  | MINUS -> "MINUS"
  | TIMES -> "TIMES"
  | DIVIDE -> "DIVIDE"
  | LPAREN -> "LPAREN"
  | RPAREN -> "RPAREN"
  | EOF -> "EOF"
;;
