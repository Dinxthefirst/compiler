open Tokens
open Ast

let rec parse_expr tokens =
  match tokens with
  | IF :: tokens' ->
    let cond, tokens'' = parse_expr tokens' in
    (match tokens'' with
     | THEN :: tokens''' ->
       let then_expr, tokens'''' = parse_expr tokens''' in
       (match tokens'''' with
        | ELSE :: tokens''''' ->
          let else_expr, tokens'''''' = parse_expr tokens''''' in
          If (cond, then_expr, else_expr), tokens''''''
        | _ -> failwith "Expected 'else'")
     | _ -> failwith "Expected 'then'")
  | LBRACE :: tokens' ->
    let stmts, tokens'' = parse_block tokens' in
    Block stmts, tokens''
  | _ -> parse_low_precedence tokens

and parse_low_precedence tokens =
  let left, tokens' = parse_high_precedence tokens in
  parse_low_precedence' left tokens'

and parse_low_precedence' left tokens =
  match tokens with
  | PLUS :: tokens' ->
    let right, tokens'' = parse_high_precedence tokens' in
    parse_low_precedence' (BinOp (left, Add, right)) tokens''
  | MINUS :: tokens' ->
    let right, tokens'' = parse_high_precedence tokens' in
    parse_low_precedence' (BinOp (left, Sub, right)) tokens''
  | EQ :: tokens' ->
    let right, tokens'' = parse_high_precedence tokens' in
    parse_low_precedence' (BinOp (left, Eq, right)) tokens''
  | LT :: tokens' ->
    let right, tokens'' = parse_high_precedence tokens' in
    parse_low_precedence' (BinOp (left, Lt, right)) tokens''
  | LTEQ :: tokens' ->
    let right, tokens'' = parse_high_precedence tokens' in
    parse_low_precedence' (BinOp (left, Lte, right)) tokens''
  | _ -> left, tokens

and parse_high_precedence tokens =
  let left, tokens' = parse_atom tokens in
  parse_high_precedence' left tokens'

and parse_high_precedence' left tokens =
  match tokens with
  | TIMES :: tokens' ->
    let right, tokens'' = parse_atom tokens' in
    parse_high_precedence' (BinOp (left, Mul, right)) tokens''
  | DIVIDE :: tokens' ->
    let right, tokens'' = parse_atom tokens' in
    parse_high_precedence' (BinOp (left, Div, right)) tokens''
  | MODULO :: tokens' ->
    let right, tokens'' = parse_atom tokens' in
    parse_high_precedence' (BinOp (left, Mod, right)) tokens''
  | _ -> left, tokens

and parse_atom tokens =
  match tokens with
  | INT i :: tokens' -> Int i, tokens'
  | BOOL b :: tokens' -> Bool b, tokens'
  | VAR v :: tokens' -> Var v, tokens'
  | MINUS :: tokens' ->
    let right, tokens'' = parse_atom tokens' in
    UnOp (Neg, right), tokens''
  | LPAREN :: tokens' ->
    let expr, tokens'' = parse_expr tokens' in
    (match tokens'' with
     | RPAREN :: tokens''' -> expr, tokens'''
     | _ -> failwith "Expected ')'")
  | DECLARATION :: VAR v :: ASSIGNMENT :: tokens' ->
    let expr, tokens'' = parse_expr tokens' in
    Decl (v, expr), tokens''
  | token ->
    failwith
      (Printf.sprintf "Unexpected token: %s" (string_of_token (List.hd token)))

and parse_statements tokens =
  let expr, tokens' = parse_expr tokens in
  match tokens' with
  | SEMICOLON :: tokens'' ->
    let expr', tokens''' = parse_statements tokens'' in
    Seq (expr, expr'), tokens'''
  | _ -> expr, tokens'

and parse_block tokens =
  let stmts, tokens' = parse_statements tokens in
  match tokens' with
  | RBRACE :: tokens'' -> stmts, tokens''
  | _ -> failwith "Expected '}'"
;;

let parse tokens =
  let ast, tokens' = parse_statements tokens in
  match tokens' with
  | EOF :: [] -> ast
  | _ ->
    failwith
      (Printf.sprintf
         "Unexpected token: %s"
         (string_of_token (List.hd tokens')))
;;
