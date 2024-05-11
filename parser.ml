%{
  open Ast
  let parse lexbuf =
    try 
      Parser.expr Lexer.token lexbuf
    with exn ->
      let curr = lexbuf.Lexing.lex_curr_p in
      let line = curr.Lexing.pos_lnum in
      let col = curr.Lexing.pos_cnum - curr.Lexing.pos_bol in
      let tok = Lexing.lexeme lexbuf in
      Printf.eprintf "Syntax error at line %d, col %d, token: %s\n" line col tok;
      exit (-1)
%}

%token <int> INT
%token <string> IDENT
%token PLUS MINUS TIMES DIVIDE EOL EOF
%start expr
%type <Ast.expr> expr = expr

%%

expr:
  | INT { Int $1 }
  | IDENT { Var $1 }
  | expr PLUS expr { Add($1, $3) }
  | expr MINUS expr { Sub($1, $3) }
  | expr TIMES expr { Mul($1, $3) }
  | expr DIVIDE expr { Div($1, $3) }

