open Tokens
open Ast

let print_failure msg tokens =
  failwith (Printf.sprintf "%s\n%s" msg (string_of_tokens tokens))
;;

let rec parse_expr tokens =
  match tokens with
  | IF :: tokens ->
    let expr, tokens = parse_if tokens in
    expr, tokens
  | LBRACE :: tokens ->
    let stmts, tokens = parse_block tokens in
    Block stmts, tokens
  | _ -> parse_low_precedence tokens

and parse_if tokens =
  let cond, tokens = parse_expr tokens in
  match tokens with
  | THEN :: tokens ->
    let then_expr, tokens = parse_expr tokens in
    (match tokens with
     | ELSE :: tokens ->
       let else_expr, tokens = parse_expr tokens in
       If (cond, then_expr, else_expr), tokens
     | _ -> print_failure "Expected 'else'" tokens)
  | _ -> print_failure "Expected 'then'" tokens

and parse_low_precedence tokens =
  let rec parse tokens left =
    match tokens with
    | OR :: tokens' ->
      let right, tokens'' = parse_and tokens' in
      parse tokens'' (BinOp (left, Or, right))
    | _ -> left, tokens
  in
  let left, tokens' = parse_and tokens in
  parse tokens' left

and parse_and tokens =
  let rec parse tokens left =
    match tokens with
    | AND :: tokens' ->
      let right, tokens'' = parse_not tokens' in
      parse tokens'' (BinOp (left, And, right))
    | _ -> left, tokens
  in
  let left, tokens' = parse_not tokens in
  parse tokens' left

and parse_not tokens =
  match tokens with
  | BANG :: tokens' ->
    let right, tokens'' = parse_relational tokens' in
    UnOp (Not, right), tokens''
  | _ -> parse_relational tokens

and parse_relational tokens =
  let rec parse tokens left =
    match tokens with
    | EQ :: tokens'
    | NEQ :: tokens'
    | LT :: tokens'
    | LTEQ :: tokens'
    | GT :: tokens'
    | GTEQ :: tokens' ->
      let right, tokens'' = parse_addition tokens' in
      parse
        tokens''
        (BinOp
           ( left
           , (match List.hd tokens with
              | EQ -> Eq
              | NEQ -> Neq
              | LT -> Lt
              | LTEQ -> Lte
              | GT -> Gt
              | GTEQ -> Gte
              | _ -> failwith "Unexpected token")
           , right ))
    | _ -> left, tokens
  in
  let left, tokens' = parse_addition tokens in
  parse tokens' left

and parse_addition tokens =
  let rec parse tokens left =
    match tokens with
    | PLUS :: tokens' | MINUS :: tokens' ->
      let right, tokens'' = parse_multiplication tokens' in
      parse
        tokens''
        (BinOp
           ( left
           , (match List.hd tokens with
              | PLUS -> Add
              | MINUS -> Sub
              | _ -> failwith "Unexpected token")
           , right ))
    | _ -> left, tokens
  in
  let left, tokens' = parse_multiplication tokens in
  parse tokens' left

and parse_multiplication tokens =
  let rec parse tokens left =
    match tokens with
    | TIMES :: tokens' | DIVIDE :: tokens' | MODULO :: tokens' ->
      let right, tokens'' = parse_exponent tokens' in
      parse
        tokens''
        (BinOp
           ( left
           , (match List.hd tokens with
              | TIMES -> Mul
              | DIVIDE -> Div
              | MODULO -> Mod
              | _ -> failwith "Unexpected token")
           , right ))
    | _ -> left, tokens
  in
  let left, tokens' = parse_exponent tokens in
  parse tokens' left

and parse_exponent tokens =
  let rec parse tokens left =
    match tokens with
    | POWER :: tokens' ->
      let right, tokens'' = parse_atom tokens' in
      parse tokens'' (BinOp (left, Pow, right))
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
  | LET :: VAR v :: ASSIGNMENT :: tokens ->
    let expr, tokens = parse_expr tokens in
    ValDecl (v, expr), tokens
  | FUNCTION :: VAR v :: LPAREN :: VAR arg :: RPAREN :: ASSIGNMENT :: tokens ->
    let expr, tokens = parse_expr tokens in
    FunDecl (v, arg, expr), tokens
  | token -> print_failure "Unexpected token: " token

and parse_statements tokens =
  let expr, tokens = parse_expr tokens in
  (* Printf.printf "\nParsing statement:\n%s\n" (string_of_ast expr); *)
  match tokens with
  | SEMICOLON :: tokens ->
    (match expr with
     | ValDecl _ | FunDecl _ ->
       let expr', tokens = parse_statements tokens in
       Seq (expr, expr'), tokens
     | _ -> print_failure "Expected declaration" tokens)
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
