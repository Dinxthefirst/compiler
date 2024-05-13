open Tokens

let rec lex_pos str pos =
  match pos, String.length str with
  | pos, len when pos >= len -> [ EOF ]
  | pos, _ ->
    (match str.[pos] with
     | ' ' | '\t' | '\n' | '\r' -> lex_pos str (pos + 1)
     | ';' -> SEMICOLON :: lex_pos str (pos + 1)
     | '{' -> LBRACE :: lex_pos str (pos + 1)
     | '}' -> RBRACE :: lex_pos str (pos + 1)
     | '(' -> LPAREN :: lex_pos str (pos + 1)
     | ')' -> RPAREN :: lex_pos str (pos + 1)
     | 'v' when str.[pos + 1] = 'a' && str.[pos + 2] = 'l' ->
       DECLARATION :: lex_pos str (pos + 3)
     | '+' -> PLUS :: lex_pos str (pos + 1)
     | '-' -> MINUS :: lex_pos str (pos + 1)
     | '*' -> TIMES :: lex_pos str (pos + 1)
     | '/' -> DIVIDE :: lex_pos str (pos + 1)
     | '%' -> MODULO :: lex_pos str (pos + 1)
     | '=' -> ASSIGNMENT :: lex_pos str (pos + 1)
     | _ ->
       if str.[pos] >= 'a' && str.[pos] <= 'z'
       then (
         let var, pos' = lex_var str pos in
         VAR var :: lex_pos str pos')
       else (
         let num, pos' = lex_int str pos in
         INT num :: lex_pos str pos'))

and lex_int str pos =
  let rec loop acc pos =
    if pos >= String.length str
    then acc, pos
    else (
      match str.[pos] with
      | '0' .. '9' ->
        let digit = int_of_char str.[pos] - int_of_char '0' in
        loop ((acc * 10) + digit) (pos + 1)
      | _ -> acc, pos)
  in
  loop 0 pos

and lex_var str pos =
  let rec loop acc pos =
    if pos >= String.length str
    then acc, pos
    else (
      match str.[pos] with
      | 'a' .. 'z' -> loop (acc ^ String.make 1 str.[pos]) (pos + 1)
      | _ -> acc, pos)
  in
  loop "" pos
;;

let lex str = lex_pos str 0
