open Tokens
open Ast

let print_failure msg tokens =
  failwith (Printf.sprintf "%s\n %s" msg (string_of_tokens tokens))
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
  | VAR v :: tokens ->
    (match tokens with
     | LPAREN :: tokens ->
       let args, tokens = parse_args tokens in
       Call (v, args), tokens
     | _ -> Var v, tokens)
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
  | FUNCTION :: tokens -> parse_fun_decl tokens
  | MATCH :: tokens ->
    let expr, tokens = parse_expr tokens in
    (match tokens with
     | WITH :: tokens ->
       Printf.printf "\nParsing match:\n%s\n" (string_of_tokens tokens);
       let cases, tokens = parse_cases tokens in
       Printf.printf
         "\nParsed cases:\n%s\n"
         (string_of_ast (Match (expr, cases)));
       Match (expr, cases), tokens
     | _ -> print_failure "Expected 'with'" tokens)
  | token -> print_failure "Unexpected token: " token

and parse_fun_decl tokens =
  match tokens with
  | VAR f :: LPAREN :: tokens ->
    let params, tokens = parse_params tokens in
    (match tokens with
     | ASSIGNMENT :: tokens ->
       let body, tokens = parse_expr tokens in
       FunDecl (f, params, body), tokens
     | _ -> print_failure "Expected '=' after function declaration" tokens)
  | _ -> print_failure "Expected function name" tokens

and parse_params tokens =
  let rec parse tokens params =
    match tokens with
    | RPAREN :: tokens -> List.rev params, tokens
    | VAR v :: tokens ->
      (match tokens with
       | COMMA :: tokens -> parse tokens (v :: params)
       | RPAREN :: tokens -> List.rev (v :: params), tokens
       | _ -> print_failure "Expected ',' or ')'" tokens)
    | _ -> print_failure "Expected variable" tokens
  in
  parse tokens []

and parse_cases tokens =
  Printf.printf "\nParsing cases:\n%s\n" (string_of_tokens tokens);
  let rec parse tokens cases =
    match tokens with
    | CASE :: tokens ->
      let expr, remaining_tokens = parse_expr tokens in
      (match remaining_tokens with
       | ARROW :: remaining_tokens ->
         let expr', remaining_tokens' = parse_statements remaining_tokens in
         parse remaining_tokens' ((expr, expr') :: cases)
       | _ -> print_failure "Expected '=>'" tokens)
    | END :: tokens -> cases, tokens
    | _ -> print_failure "Expected 'end'" tokens
  in
  let cases, tokens = parse tokens [] in
  cases, tokens

and parse_args tokens =
  let rec parse tokens args =
    match tokens with
    | RPAREN :: tokens -> args, tokens
    | _ ->
      let arg, tokens = parse_expr tokens in
      (match tokens with
       | COMMA :: tokens -> parse tokens (arg :: args)
       | RPAREN :: tokens -> List.rev (arg :: args), tokens
       | _ -> print_failure "Expected ',' or ')'" tokens)
  in
  parse tokens []

and parse_statements tokens =
  let expr, tokens = parse_expr tokens in
  Printf.printf "\nParsing statement:\n%s\n" (string_of_ast expr);
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
  Printf.printf "\nParsing block:\n%s\n" (string_of_ast stmts);
  match tokens with
  | RBRACE :: tokens -> stmts, tokens
  | _ -> print_failure "Expected '}'" tokens
;;

let parse tokens =
  Printf.printf "Parsing:\n%s\n" (string_of_tokens tokens);
  let ast, tokens = parse_statements tokens in
  match tokens with
  | EOF :: [] -> ast
  | _ ->
    failwith
      (Printf.sprintf
         "PARSING FAILED\nUnexpected token: %s"
         (string_of_token (List.hd tokens)))
;;
