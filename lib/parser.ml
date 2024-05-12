open Tokens
open Ast

let rec parse_expr tokens = parse_low_precedence tokens

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
  | _ -> left, tokens

and parse_atom tokens =
  match tokens with
  | INT i :: tokens' -> Int i, tokens'
  | LPAREN :: tokens' ->
    let expr, tokens'' = parse_expr tokens' in
    (match tokens'' with
     | RPAREN :: tokens''' -> expr, tokens'''
     | _ -> failwith "Expected ')'")
  | token ->
    failwith (Printf.sprintf "Unexpected token: %s" (string_of_token (List.hd token)))
;;

let parse tokens =
  let expr, tokens' = parse_expr tokens in
  match tokens' with
  | [] -> expr
  | EOF :: _ -> expr
  | _ ->
    failwith (Printf.sprintf "Unexpected token: %s" (string_of_token (List.hd tokens')))
;;
