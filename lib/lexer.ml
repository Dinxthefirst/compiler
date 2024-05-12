open Tokens

let rec lex_pos str pos =
  match pos, String.length str with
  | pos, len when pos >= len -> [ EOF ]
  | pos, _ ->
    (match str.[pos] with
     | ' ' | '\t' | '\n' | '\r' -> lex_pos str (pos + 1)
     | '(' -> LPAREN :: lex_pos str (pos + 1)
     | ')' -> RPAREN :: lex_pos str (pos + 1)
     | '+' -> PLUS :: lex_pos str (pos + 1)
     | '-' -> MINUS :: lex_pos str (pos + 1)
     | '*' -> TIMES :: lex_pos str (pos + 1)
     | '/' -> DIVIDE :: lex_pos str (pos + 1)
     | _ ->
       let num, pos' = lex_int str pos in
       INT num :: lex_pos str pos')

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
;;

let lex str = lex_pos str 0
