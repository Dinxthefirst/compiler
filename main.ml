let () =
  let filename = Sys.argv.(1) in
  let in_channel = open_in filename in
  let lexbuf = Lexing.from_channel in_channel in
  try
    let ast = Parser.program Lexer.token lexbuf in
    let result = Evaluator.eval ast in
    print_int result;
    print_newline ();
    close_in in_channel
  with
  | Lexer.Error msg -> 
    Printf.eprintf "%s%!" msg;
    exit (-1)
  | Parser.Error ->
    let pos = lexbuf.lex_curr_p in
    Printf.eprintf "Syntax error at line %d, position %d\n%!" pos.pos_lnum (pos.pos_cnum - pos.pos_bol);
    exit (-1)