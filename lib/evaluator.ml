open Ast

let rec evaluate_expr = function
  | Int i -> i
  | BinOp (e1, op, e2) ->
    let v1 = evaluate_expr e1 in
    let v2 = evaluate_expr e2 in
    (match op with
     | Add -> v1 + v2
     | Sub -> v1 - v2
     | Mul -> v1 * v2
     | Div -> v1 / v2)
  | UnOp (op, e) ->
    let v = evaluate_expr e in
    (match op with
     | Neg -> -v)
;;

let evaluate expr = evaluate_expr expr |> string_of_int
