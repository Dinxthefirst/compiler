open Tokens

let rec lex_pos str pos =
  match pos, String.length str with
  | pos, len when pos >= len -> [ EOF ]
  | pos, _ ->
    let pos = skip_whitespace str pos in
    (match str.[pos] with
     | ';' -> SEMICOLON :: lex_pos str (pos + 1)
     | '{' -> LBRACE :: lex_pos str (pos + 1)
     | '}' -> RBRACE :: lex_pos str (pos + 1)
     | '(' -> LPAREN :: lex_pos str (pos + 1)
     | ')' -> RPAREN :: lex_pos str (pos + 1)
     | '+' -> PLUS :: lex_pos str (pos + 1)
     | '-' -> MINUS :: lex_pos str (pos + 1)
     | '*' -> TIMES :: lex_pos str (pos + 1)
     | '/' -> DIVIDE :: lex_pos str (pos + 1)
     | '%' -> MODULO :: lex_pos str (pos + 1)
     | '=' ->
       (match peek str (pos + 1) with
        | Some '=' -> EQ :: lex_pos str (pos + 2)
        | _ -> ASSIGNMENT :: lex_pos str (pos + 1))
     | '<' ->
       (match peek str (pos + 1) with
        | Some '=' -> LTEQ :: lex_pos str (pos + 2)
        | _ -> LT :: lex_pos str (pos + 1))
     | '0' .. '9' ->
       let num, pos' = lex_int str pos in
       INT num :: lex_pos str pos'
     | 'a' .. 'z' | 'A' .. 'Z' ->
       let rec aux pos' =
         if pos' < String.length str && is_alphanumeric str.[pos']
         then aux (pos' + 1)
         else pos'
       in
       let end_pos = aux pos in
       let var = String.sub str pos (end_pos - pos) in
       let token =
         match var with
         | "val" -> DECLARATION
         | "if" -> IF
         | "then" -> THEN
         | "else" -> ELSE
         | "true" -> BOOL true
         | "false" -> BOOL false
         | _ -> VAR var
       in
       token :: lex_pos str end_pos
     | _ -> raise (Invalid_argument "lex_pos"))

and peek str pos = if pos >= String.length str then None else Some str.[pos]

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

and skip_whitespace str pos =
  if pos >= String.length str
  then pos
  else (
    match str.[pos] with
    | ' ' | '\t' | '\n' | '\r' -> skip_whitespace str (pos + 1)
    | _ -> pos)

and is_alphanumeric c = is_alpha c || is_digit c || c = '_'
and is_alpha c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
and is_digit c = c >= '0' && c <= '9'

(* and lex_var str pos =
   let rec loop acc pos =
   if pos >= String.length str
   then acc, pos
   else (
   match str.[pos] with
   | 'a' .. 'z' -> loop (acc ^ String.make 1 str.[pos]) (pos + 1)
   | _ -> acc, pos)
   in
   loop "" pos *)

let lex str = lex_pos str 0
