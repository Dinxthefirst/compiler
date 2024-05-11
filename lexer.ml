{
    open Parser
}

rule token = parse
    | [' ' '\t'] { token lexbuf } 
    | ['\n'] { EOL }
    | ['0'-'9']+ as lxm { INT(int_of_string lxm) }
    | ['a'-'z' 'A'-'Z' '_']['a'-'z' 'A'-'Z' '0'-'9' '_']* as lxm { IDENT lxm }
    | '+' { PLUS }
    | '-' { MINUS }
    | '*' { TIMES }
    | '/' { DIVIDE }
    | eof { EOF }
