open Tokens
open Ast

let print_failure msg tokens =
  failwith (Printf.sprintf "%s\n%s" msg (string_of_tokens tokens))
;;

let rec parse_expr tokens =
  match tokens with
  | IF :: tokens ->
    let cond, tokens = parse_expr tokens in
    (match tokens with
     | THEN :: tokens ->
       let then_expr, tokens = parse_expr tokens in
       (match tokens with
        | ELSE :: tokens ->
          let else_expr, tokens = parse_expr tokens in
          If (cond, then_expr, else_expr), tokens
        | _ -> print_failure "Expected 'else'" tokens)
     | _ -> print_failure "Expected 'then'" tokens)
  | LBRACE :: tokens ->
    let stmts, tokens = parse_block tokens in
    Block stmts, tokens
  | _ -> parse_low_precedence tokens

and parse_low_precedence tokens =
  let rec parse tokens left =
    match tokens with
    | PLUS :: tokens' ->
      let right, tokens'' = parse_high_precedence tokens' in
      parse tokens'' (BinOp (left, Add, right))
    | MINUS :: tokens' ->
      let right, tokens'' = parse_high_precedence tokens' in
      parse tokens'' (BinOp (left, Sub, right))
    | EQ :: tokens' ->
      let right, tokens'' = parse_high_precedence tokens' in
      parse tokens'' (BinOp (left, Eq, right))
    | NEQ :: tokens' ->
      let right, tokens'' = parse_high_precedence tokens' in
      parse tokens'' (BinOp (left, Neq, right))
    | LT :: tokens' ->
      let right, tokens'' = parse_high_precedence tokens' in
      parse tokens'' (BinOp (left, Lt, right))
    | LTEQ :: tokens' ->
      let right, tokens'' = parse_high_precedence tokens' in
      parse tokens'' (BinOp (left, Lte, right))
    | _ -> left, tokens
  in
  let left, tokens' = parse_high_precedence tokens in
  parse tokens' left

and parse_high_precedence tokens =
  let rec parse tokens left =
    match tokens with
    | TIMES :: tokens' ->
      let right, tokens'' = parse_atom tokens' in
      parse tokens'' (BinOp (left, Mul, right))
    | DIVIDE :: tokens' ->
      let right, tokens'' = parse_atom tokens' in
      parse tokens'' (BinOp (left, Div, right))
    | MODULO :: tokens' ->
      let right, tokens'' = parse_atom tokens' in
      parse tokens'' (BinOp (left, Mod, right))
    | _ -> left, tokens
  in
  let left, tokens' = parse_atom tokens in
  parse tokens' left

and parse_atom tokens =
  match tokens with
  | INT i :: tokens -> Int i, tokens
  | BOOL b :: tokens -> Bool b, tokens
  | VAR v :: tokens -> Var v, tokens
  | MINUS :: tokens ->
    let right, tokens = parse_atom tokens in
    UnOp (Neg, right), tokens
  | BANG :: tokens ->
    let right, tokens = parse_atom tokens in
    UnOp (Not, right), tokens
  | LPAREN :: tokens ->
    let expr, tokens = parse_expr tokens in
    (match tokens with
     | RPAREN :: tokens -> expr, tokens
     | _ -> print_failure "Expected ')'" tokens)
  | DECLARATION :: VAR v :: ASSIGNMENT :: tokens ->
    let expr, tokens = parse_expr tokens in
    Decl (v, expr), tokens
  | token -> print_failure "Unexpected token: " token

and parse_statements tokens =
  let expr, tokens = parse_expr tokens in
  (* Printf.printf "\nParsing statement:\n%s\n" (string_of_ast expr); *)
  match tokens with
  | SEMICOLON :: tokens ->
    let expr', tokens = parse_statements tokens in
    Seq (expr, expr'), tokens
  | _ -> expr, tokens

and parse_block tokens =
  let stmts, tokens = parse_statements tokens in
  (* Printf.printf "\nParsing block:\n%s\n" (string_of_ast stmts); *)
  match tokens with
  | RBRACE :: tokens -> stmts, tokens
  | _ -> print_failure "Expected '}'" tokens
;;

let parse tokens =
  (* Printf.printf "Parsing:\n%s\n" (string_of_tokens tokens); *)
  let ast, tokens = parse_statements tokens in
  match tokens with
  | EOF :: [] -> ast
  | _ ->
    failwith
      (Printf.sprintf
         "PARSING FAILED\nUnexpected token: %s"
         (string_of_token (List.hd tokens)))
;;
