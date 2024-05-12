{
  open Parser
}

rule token = parse
| [' ' '\t'] { token lexbuf }  (* Skip whitespace *)
| ['0'-'9']+ as lxm { INT(int_of_string lxm) }
| '+' { PLUS }
| '-' { MINUS }
| '*' { TIMES }
| '/' { DIV }
| '(' { LPAREN }
| ')' { RPAREN }
| eof { EOF }
| _ { raise (Failure "unexpected character") }